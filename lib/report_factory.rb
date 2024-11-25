# frozen_string_literal: true

class ReportFactory < BaseService # rubocop:disable Metrics/ClassLength
  include DocytLib::Helpers::PerformanceHelpers
  include DocytLib::Async::Publisher

  # Higher numbers indicate higher priority in RabbitMQ
  # The default priority of a message is 5
  MANUAL_UPDATE_PRIORITY = 50

  DEPARTMENT_REPORT_COLUMNS = [
    { type: 'actual', range: 'current_period', year: 'current', name: 'PTD $' },
    { type: 'budget_actual', range: 'current_period', year: 'current', name: 'Budget $' },
    { type: 'budget_percentage', range: 'current_period', year: 'current', name: 'Budget %' },
    { type: 'budget_variance', range: 'current_period', year: 'current', name: 'Budget Var' }
  ].freeze

  def enqueue_report_update(report)
    report.update!(update_state: Report::UPDATE_STATE_QUEUED)
    report_service = report.report_service
    publish(events.refresh_reports(report_service_id: report_service.id.to_s,
                                   report_id: report.id.to_s), priority: ReportFactory::MANUAL_UPDATE_PRIORITY)
  end

  def enqueue_report_data_update(report_data)
    report_data.update!(update_state: Report::UPDATE_STATE_QUEUED)
    publish(events.refresh_report_data(report_data_id: report_data.id.to_s), priority: ReportFactory::MANUAL_UPDATE_PRIORITY)
  end

  def refill_report(report:)
    report.update!(update_state: Report::UPDATE_STATE_STARTED)
    fetch_business_information(report.report_service)
    fetch_business_vendors(business_id: report.report_service.business_id) if report.vendor_report?
    fetch_bookkeeping_start_date(report.report_service)
    sync_report_infos(report: report)
    refill_report_datas(report: report, bookkeeping_start_date: @bookkeeping_start_date)
  rescue StandardError => e
    report.update!(update_state: Report::UPDATE_STATE_FAILED, error_msg: e.message)
    Rollbar.error(e)
    DocytLib.logger.debug(e.message)
  end

  def refill_report_datas(report:, bookkeeping_start_date:)
    refresh_monthly_report_datas(report: report, bookkeeping_start_date: bookkeeping_start_date)
    report.update!(updated_at: Time.zone.now, update_state: Report::UPDATE_STATE_FINISHED)
  end
  apm_method :refill_report_datas

  def refill_daily_report_data(report_data:) # rubocop:disable Metrics/AbcSize
    report_data.dependencies.each(&:refresh)
    fetch_bookkeeping_start_date(report_data.report.report_service)
    return unless report_data.daily? && should_update(report_data)

    DocytLib.logger.info(
      "Update Daily Report: #{report_data.report.id} Year: #{report_data.start_date.year} Month: #{report_data.start_date.month} Date: #{report_data.start_date.mday}"
    )
    fetch_business_information(report_data.report.report_service)
    fetch_business_vendors(business_id: report_data.report.report_service.business_id) if report_data.report.vendor_report?
    report_data.clear_values
    fill_report_data(report_data: report_data)
  end

  def update_report_users(report:, current_user:)
    report.report_users.destroy_all if report.report_users.count.positive?
    user_api_instance = DocytServerClient::UserApi.new
    user_ids = user_api_instance.report_service_admin_users(report.report_service.service_id).users.map(&:id)
    user_ids.each do |user_id|
      report.report_users.create!(user_id: user_id)
    end
    return if current_user.nil? || user_ids.include?(current_user.id)

    report.report_users.create!(user_id: current_user.id)
  end

  def force_update_without_condition(report:)
    report.refresh_all_report_datas(ReportFactory::MANUAL_UPDATE_PRIORITY)
  end

  def update(report:, report_params:) # rubocop:disable Metrics/MethodLength
    report.update!(name: report_params[:name]) if report_params[:name].present?
    report.update!(accepted_accounting_class_ids: report_params[:accepted_accounting_class_ids]) unless report_params[:accepted_accounting_class_ids].nil?
    unless report_params[:accepted_account_types].nil?
      account_types = []
      report_params[:accepted_account_types].each { |aat| account_types << { account_type: aat[:account_type], account_detail_type: aat[:account_detail_type] } }
      report.update!(accepted_account_types: account_types)
    end
    return if report_params[:user_ids].nil?

    report.report_users.destroy_all
    report_params[:user_ids].each do |user_id|
      report.report_users.create!(user_id: user_id)
    end
  end

  def grant_access(report:, user_id:)
    report.report_users.create!(user_id: user_id)
  end

  def revoke_access(report:, user_id:)
    report_user = report.report_users.find_by(id: user_id)
    report_user.destroy!
  end

  def sync_report_infos(report:)
    if report.template_id == Report::DEPARTMENT_REPORT
      sync_departmental_report_infos(report: report)
    else
      report_template = ReportTemplate.find_by(template_id: report.template_id)
      sync_advanced_report_infos(report: report, report_template: report_template)
    end
  end

  private

  def should_update(report_data)
    report_data.dependencies.any?(&:has_changed?)
  end

  def refresh_monthly_report_datas(report:, bookkeeping_start_date:) # rubocop:disable Metrics/MethodLength
    current_date = bookkeeping_start_date
    current_date = Date.new(current_date.year, 1, 1)
    january_report_data_required = report.january_report_data_required?
    while current_date <= Time.zone.today
      start_date = Date.new(current_date.year, current_date.month, 1)
      end_date = Date.new(current_date.year, current_date.month, -1)
      report_data = report.report_datas.find_by(start_date: start_date, end_date: end_date, period_type: ReportData::PERIOD_MONTHLY)
      if report_data.present?
        unless should_update(report_data)
          current_date += 1.month
          next
        end
        report_data.destroy!
      end

      current_date += 1.month
      create_report_data(report: report, start_date: start_date, end_date: end_date,
                         january_report_data_required: january_report_data_required, period_type: ReportData::PERIOD_MONTHLY)
    end
  end

  def create_report_data(report:, start_date:, end_date:, january_report_data_required:, period_type:)
    report_data = report.report_datas.create!(start_date: start_date, end_date: end_date, period_type: period_type)
    DocytLib.logger.info("Update Report: #{report_data.report.id} Year: #{report_data.start_date.year} Month: #{report_data.start_date.month}")
    fill_report_data(report_data: report_data, january_report_data_required: january_report_data_required)
  end

  def fill_report_data(report_data:, january_report_data_required: nil)
    ItemValueFactory.generate_batch(
      report_data: report_data, dependent_report_datas: report_data.dependent_report_datas,
      all_business_chart_of_accounts: @all_business_chart_of_accounts,
      all_business_vendors: @business_vendors,
      accounting_classes: @accounting_classes,
      qbo_ledgers: qbo_ledgers(report_data: report_data),
      january_report_data_of_current_year: january_report_data(report: report_data.report, report_data: report_data,
                                                               january_report_data_required: january_report_data_required)
    )
    report_data.recalc_digest
  end
  apm_method :create_report_data

  def january_report_data(report:, report_data:, january_report_data_required:)
    return nil unless january_report_data_required
    return nil if report_data.start_date.month == 1

    start_date = Date.new(report_data.start_date.year, 1, 1)
    end_date = Date.new(report_data.start_date.year, 1, -1)
    report.report_datas.where(period_type: ReportData::PERIOD_MONTHLY, start_date: start_date,
                              end_date: end_date).first
  end

  def qbo_ledgers(report_data:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    previous_period =
      if report_data.daily?
        Quickbooks::BalanceSheetGeneralLedger.find_by(
          report_service: report_data.report.report_service,
          start_date: report_data.start_date - 1.day, end_date: report_data.start_date - 1.day
        )
      else
        Quickbooks::BalanceSheetGeneralLedger.find_by(
          report_service: report_data.report.report_service,
          start_date: report_data.start_date - 1.month, end_date: report_data.start_date - 1.day
        )
      end
    qbo_ledgers = {
      Quickbooks::CommonGeneralLedger => report_data.common_general_ledger,
      Quickbooks::BalanceSheetGeneralLedger => {
        current_period: Quickbooks::BalanceSheetGeneralLedger.find_by(
          report_service: report_data.report.report_service,
          start_date: report_data.start_date, end_date: report_data.end_date
        ),
        previous_period: previous_period,
        current_mtd: Quickbooks::BalanceSheetGeneralLedger.find_by(
          report_service: report_data.report.report_service,
          start_date: report_data.general_ledger_start_date, end_date: report_data.end_date
        ),
        previous_mtd: Quickbooks::BalanceSheetGeneralLedger.find_by(
          report_service: report_data.report.report_service,
          start_date: report_data.general_ledger_start_date, end_date: report_data.end_date - 1.day
        )
      }
    }
    if report_data.report.departmental_report?
      qbo_ledgers[Quickbooks::RevenueGeneralLedger] = report_data.revenue_general_ledger
      qbo_ledgers[Quickbooks::ExpensesGeneralLedger] = report_data.expenses_general_ledger
    end
    if report_data.report.revenue_accounting_report? || report_data.report.revenue_report?
      qbo_ledgers[Quickbooks::BankGeneralLedger] = report_data.bank_general_ledger
      qbo_ledgers[Quickbooks::AccountsPayableGeneralLedger] = report_data.ap_general_ledger
    end
    qbo_ledgers
  end

  def sync_departmental_report_infos(report:)
    sync_department_items(report: report)
    columns = []
    DEPARTMENT_REPORT_COLUMNS.each { |column| columns << ReportTemplate::Column.new(column) }
    sync_columns_with_template(report: report, columns: columns)
  end

  def sync_advanced_report_infos(report:, report_template:)
    sync_columns_with_template(report: report, columns: report_template.columns)
    sync_items_with_template(report: report, items: report_template.items)
    sync_depends_with_template(report: report, dependent_ids: report_template.depends_on)
    sync_missing_transactions_calculation_disabled_with_template(report: report, disabled: report_template.missing_transactions_calculation_disabled)
    sync_enabled_budget_compare(report: report, enabled_budget_compare: report_template.enabled_budget_compare)
    sync_visible_total_column(report: report, total_column_visible: report_template.total_column_visible)
    sync_view_by_options(report: report, view_by_options: report_template.view_by_options)
    sync_enabled_blank_value_for_metric(report: report, enabled_blank_value_for_metric: report_template.enabled_blank_value_for_metric)
    sync_edit_mapping_disabled(report: report, edit_mapping_disabled: report_template.edit_mapping_disabled)
  end

  def sync_depends_with_template(report:, dependent_ids:)
    report.update!(dependent_template_ids: dependent_ids) unless dependent_ids.nil?
  end

  def sync_missing_transactions_calculation_disabled_with_template(report:, disabled:)
    report.update!(missing_transactions_calculation_disabled: disabled) unless disabled.nil?
  end

  def sync_view_by_options(report:, view_by_options:)
    report.update!(view_by_options: view_by_options) unless view_by_options.nil?
  end

  def sync_enabled_budget_compare(report:, enabled_budget_compare:)
    report.update!(enabled_budget_compare: enabled_budget_compare) unless enabled_budget_compare.nil?
  end

  def sync_visible_total_column(report:, total_column_visible:)
    report.update!(total_column_visible: total_column_visible) unless total_column_visible.nil?
  end

  def sync_enabled_blank_value_for_metric(report:, enabled_blank_value_for_metric:)
    report.update!(enabled_blank_value_for_metric: enabled_blank_value_for_metric) unless enabled_blank_value_for_metric.nil?
  end

  def sync_edit_mapping_disabled(report:, edit_mapping_disabled:)
    report.update!(edit_mapping_disabled: edit_mapping_disabled) unless edit_mapping_disabled.nil?
  end

  def sync_items_with_template(report:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return if items.blank?

    parent_order = 0
    parent_ids = []
    items.each do |item_json|
      next if item_json.parent_id.present?

      parent_item = report.items.find_by(identifier: item_json.id)
      if parent_item.present?
        parent_item.update!(name: item_json.name,
                            order: parent_order,
                            show: item_json.show.nil? ? true : item_json.show,
                            totals: item_json.totals || false,
                            depth_diff: item_json.depth_diff || 0,
                            type_config: item_json.type,
                            values_config: item_json.values)
      else
        parent_item = report.items.create!(name: item_json.name,
                                           order: parent_order,
                                           identifier: item_json.id,
                                           show: item_json.show.nil? ? true : item_json.show,
                                           totals: item_json.totals || false,
                                           depth_diff: item_json.depth_diff || 0,
                                           type_config: item_json.type,
                                           values_config: item_json.values)
      end
      parent_order += 1
      parent_ids << parent_item.id.to_s
      sync_child_items_with_template(parent_item: parent_item, items: items)
    end

    report.items.where.not(_id: { '$in': parent_ids }).destroy_all
  end

  def sync_child_items_with_template(parent_item:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    child_order = 0
    child_ids = []
    items.each do |child_item_json| # rubocop:disable Metrics/BlockLength
      next if child_item_json.parent_id != parent_item.identifier

      child_item = parent_item.child_items.find_by(identifier: child_item_json.id)
      if child_item.present?
        child_item.update!(name: child_item_json.name,
                           order: child_order,
                           show: child_item_json.show.nil? ? true : child_item_json.show,
                           totals: child_item_json.totals || false,
                           negative: child_item_json.negative || false,
                           negative_for_total: child_item_json.negative_for_total || false,
                           depth_diff: child_item_json.depth_diff || 0,
                           type_config: child_item_json.type,
                           values_config: child_item_json.values,
                           account_type: child_item_json.account_type)
      else
        child_item = parent_item.child_items.create!(name: child_item_json.name,
                                                     order: child_order,
                                                     identifier: child_item_json.id,
                                                     show: child_item_json.show.nil? ? true : child_item_json.show,
                                                     totals: child_item_json.totals || false,
                                                     negative: child_item_json.negative || false,
                                                     negative_for_total: child_item_json.negative_for_total || false,
                                                     depth_diff: child_item_json.depth_diff || 0,
                                                     type_config: child_item_json.type,
                                                     values_config: child_item_json.values,
                                                     account_type: child_item_json.account_type)
      end
      child_order += 1
      child_ids << child_item.id.to_s
      sync_child_items_with_template(parent_item: child_item, items: items)
    end

    parent_item.child_items.where.not(_id: { '$in': child_ids }).destroy_all
  end

  def sync_department_items(report:) # rubocop:disable Metrics/MethodLength
    root_items = [
      { "identifier": 'revenue', "name": 'Revenue' },
      { "identifier": 'expenses', "name": 'Expenses' },
      { "identifier": 'profit', "name": 'Profit' }
    ]
    parent_order = 0
    parent_ids = []
    root_items.each do |root_item|
      parent_item = report.items.detect { |item| item.identifier == root_item[:identifier] }
      if parent_item.present?
        parent_item.update!(name: root_item[:name], order: parent_order, totals: false)
      else
        parent_item = report.items.create!(name: root_item[:name], order: parent_order, identifier: root_item[:identifier])
      end
      parent_order += 1
      parent_ids << parent_item.id.to_s
      sync_department_child_items(parent_item: parent_item, parent_class_external_id: nil, identifier_prefix: root_item[:identifier], first_step: true)
    end

    report.items.where.not(_id: { '$in': parent_ids }).destroy_all
  end

  def sync_department_child_items(parent_item:, parent_class_external_id:, identifier_prefix:, first_step:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    child_accounting_classes = @accounting_classes.select { |accounting_class| accounting_class.parent_external_id == parent_class_external_id }

    child_order = 0
    child_ids = []
    child_accounting_classes.each do |child_accounting_class|
      child_identifier = "#{identifier_prefix}_#{child_accounting_class.external_id}"
      sub_child_classes = @accounting_classes.select { |accounting_class| accounting_class.parent_external_id == child_accounting_class.external_id }
      type_config = sub_child_classes.blank? ? { name: 'quickbooks_ledger' } : nil
      child_item = parent_item.child_items.detect { |item| item.identifier == child_identifier }
      if child_item.present?
        child_item.update!(name: child_accounting_class.name, order: child_order, totals: false, type_config: type_config)
        child_item.item_accounts.destroy_all
      else
        child_item = parent_item.child_items.create!(name: child_accounting_class.name, order: child_order,
                                                     identifier: child_identifier,
                                                     show: true, negative: false, type_config: type_config)
      end
      child_item.item_accounts.create!(accounting_class_id: child_accounting_class.id)
      child_order += 1
      child_ids << child_item.id.to_s
      sync_department_child_items(parent_item: child_item, parent_class_external_id: child_accounting_class.external_id,
                                  identifier_prefix: child_item.identifier, first_step: false)
    end
    if child_accounting_classes.present?
      total_item = sync_department_total_item(parent_item: parent_item, child_order: child_order, first_step: first_step, parent_class_external_id: parent_class_external_id)
      child_ids << total_item.id.to_s
    end

    parent_item.child_items.where.not(_id: { '$in': child_ids }).destroy_all
  end

  def sync_department_total_item(parent_item:, child_order:, first_step:, parent_class_external_id:) # rubocop:disable Metrics/MethodLength
    child_identifier = "total_#{parent_item.identifier}"
    child_item = parent_item.child_items.detect { |item| item.identifier == child_identifier }
    if child_item.present?
      child_item.item_accounts.destroy_all
    elsif child_item.blank?
      child_item = parent_item.child_items.create!(name: "Total #{parent_item.name}", order: child_order,
                                                   identifier: child_identifier,
                                                   show: first_step, negative: false, totals: true)
    end
    parent_accounting_class = @accounting_classes.detect { |accounting_class| accounting_class.external_id == parent_class_external_id }
    child_item.item_accounts.create!(accounting_class_id: parent_accounting_class.id) if parent_accounting_class.present?

    child_item
  end

  def sync_columns_with_template(report:, columns:) # rubocop:disable Metrics/MethodLength
    column_ids = []
    order = 0
    columns.each do |column|
      column_object = report.columns.find_by(type: column.type, range: column.range, year: column.year)
      if column_object.present?
        column_object.update!(order: order, name: column.name)
      else
        column_object = report.columns.create!(type: column.type, range: column.range, year: column.year, name: column.name, order: order)
      end
      column_ids << column_object.id.to_s
      order += 1
    end
    report.columns.where.not(_id: { '$in': column_ids }).destroy_all
  end
end
