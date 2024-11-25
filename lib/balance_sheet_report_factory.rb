# frozen_string_literal: true

class BalanceSheetReportFactory < ReportFactory # rubocop:disable Metrics/ClassLength
  attr_accessor(:report)

  def create(report_service:)
    @report = BalanceSheetReport.find_or_create_by!(
      report_service: report_service,
      template_id: BalanceSheetReport::BALANCE_SHEET_REPORT,
      name: BalanceSheetReport::BALANCE_SHEET_REPORT_NAME
    )
    sync_report_infos(report: @report)
  end

  private

  def sync_report_infos(report:)
    fetch_all_business_chart_of_accounts(business_id: report.report_service.business_id)
    report_template = ReportTemplate.find_by(template_id: report.template_id)
    sync_balance_sheet_report_infos(report: report, report_template: report_template)
  end

  def sync_balance_sheet_report_infos(report:, report_template:)
    sync_columns_with_template(report: report, columns: report_template.columns)
    sync_items_with_template(report: report, items: report_template.items)
    sync_depends_with_template(report: report, dependent_ids: report_template.depends_on)
    sync_enabled_budget_compare(report: report, enabled_budget_compare: report_template.enabled_budget_compare)
    sync_visible_total_column(report: report, total_column_visible: report_template.total_column_visible)
    sync_accounting_class_check_disabled_with_template(report: report, disabled: report_template.accounting_class_check_disabled)
    report.save!
  end

  def sync_accounting_class_check_disabled_with_template(report:, disabled:)
    report.update!(accounting_class_check_disabled: disabled) unless disabled.nil?
  end

  def sync_items_with_template(report:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    parent_order = 0
    parent_ids = []
    items.each do |item_json|
      next if item_json.parent_id.present?

      parent_item = report.items.find_or_initialize_by(identifier: item_json.id)
      parent_item.name = item_json.name
      parent_item.order = parent_order
      parent_item.totals = false
      parent_item.type_config = item_json.type
      parent_item.values_config = item_json.values
      parent_item.save!

      parent_order += 1
      parent_ids << parent_item.id.to_s
      sync_child_items_with_template(parent_item: parent_item, items: items)
    end

    report.items.where.not(_id: { '$in': parent_ids }).destroy_all
  end

  def sync_child_items_with_template(parent_item:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    child_order = 0
    child_ids = []
    items.each do |child_item_json|
      next if child_item_json.parent_id != parent_item.identifier

      child_item = parent_item.child_items.find_or_initialize_by(identifier: child_item_json.id)
      child_item.name = child_item_json.name
      child_item.order = child_order
      child_item.totals = child_item_json.totals || false
      child_item.show = child_item_json.show.nil? || child_item_json.show
      child_item.negative = child_item_json.negative || false
      child_item.negative_for_total = child_item_json.negative_for_total || false
      child_item.depth_diff = child_item_json.depth_diff || 0
      child_item.type_config = child_item_json.type
      child_item.values_config = child_item_json.values
      child_item.account_type = child_item_json.account_type
      child_item.save!

      child_order += 1
      child_ids << child_item.id.to_s

      if child_item_json.account_type.present?
        generate_balance_sheet_parent_items(parent_item: child_item, items: items)
      else
        sync_child_items_with_template(parent_item: child_item, items: items)
      end
    end

    parent_item.child_items.where.not(_id: { '$in': child_ids }).destroy_all
  end

  def generate_balance_sheet_parent_items(parent_item:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    child_order = 0
    child_ids = []
    second_arg_id = second_arg_item_id(item: parent_item)
    chart_of_accounts = @all_business_chart_of_accounts.select { |bcoa| parent_item.account_type == bcoa.acc_type && bcoa.parent_id.nil? }
    chart_of_accounts.each do |chart_of_account|
      item = parent_item.child_items.find_or_initialize_by(identifier: chart_of_account.id.to_s)
      item.name = chart_of_account.name
      item.order = child_order
      item.totals = false
      item.type_config = type_config
      item.values_config = values_config(second_arg_id: second_arg_id, item_id: chart_of_account.id.to_s)
      item.save!

      child_ids << item.id.to_s
      child_order += 1

      sync_item_accounts(item: item, chart_of_account: chart_of_account)

      child_cas = @all_business_chart_of_accounts.select { |bcoa| chart_of_account.chart_of_account_id == bcoa.parent_id }
      generate_balance_sheet_child_items(parent_item: item, child_chart_of_accounts: child_cas, second_arg_id: second_arg_id) if child_cas.present?
    end

    items.each do |item_json|
      next if item_json.parent_id != parent_item.identifier

      fixed_item = parent_item.child_items.find_or_initialize_by(identifier: item_json.id)
      fixed_item.name = item_json.name
      fixed_item.order = child_order
      fixed_item.totals = item_json.totals || false
      fixed_item.show = item_json.show.nil? || item_json.show
      fixed_item.negative = item_json.negative || false
      fixed_item.negative_for_total = item_json.negative_for_total || false
      fixed_item.depth_diff = item_json.depth_diff || 0
      fixed_item.type_config = item_json.type
      fixed_item.values_config = item_json.values
      fixed_item.save!
      child_ids << fixed_item.id.to_s
      child_order += 1
    end

    parent_item.child_items.where.not(_id: { '$in': child_ids }).destroy_all
  end

  def generate_balance_sheet_child_items(parent_item:, child_chart_of_accounts:, second_arg_id:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    child_order = 0
    child_ids = []
    child_chart_of_accounts.each do |chart_of_account|
      child_cas = @all_business_chart_of_accounts.select { |bcoa| chart_of_account.chart_of_account_id == bcoa.parent_id }

      child_item = parent_item.child_items.find_or_initialize_by(identifier: chart_of_account.id.to_s)
      child_item.name = chart_of_account.name
      child_item.order = child_order
      child_item.totals = false
      child_item.type_config = type_config
      child_item.values_config = values_config(second_arg_id: second_arg_id, item_id: chart_of_account.id.to_s)
      child_item.save!

      child_ids << child_item.id.to_s
      child_order += 1

      sync_item_accounts(item: child_item, chart_of_account: chart_of_account)
      generate_balance_sheet_child_items(parent_item: child_item, child_chart_of_accounts: child_cas, second_arg_id: second_arg_id) if child_cas.present?
    end
    total_item = sync_total_item(parent_item: parent_item, second_arg_id: second_arg_id, child_order: child_order)
    child_ids << total_item.id.to_s

    parent_item.child_items.where.not(_id: { '$in': child_ids }).destroy_all
  end

  def sync_item_accounts(item:, chart_of_account:)
    item.item_accounts.destroy_all
    item.item_accounts.find_or_create_by!(chart_of_account_id: chart_of_account.chart_of_account_id)
  end

  def sync_total_item(parent_item:, second_arg_id:, child_order:)
    child_identifier = "total_#{parent_item.identifier}"
    total_item = parent_item.child_items.find_or_initialize_by(identifier: child_identifier)
    total_item.name = "Total #{parent_item.name}"
    total_item.order = child_order
    total_item.totals = true
    total_item.values_config = values_config(second_arg_id: second_arg_id, item_id: child_identifier)
    total_item.save!
    total_item
  end

  def second_arg_item_id(item:)
    stats_formula = item.values_config[Column::TYPE_PERCENTAGE]
    expression = stats_formula['value']['expression']
    expression['arg2']['item_id']
  end

  def type_config
    {
      'name' => 'quickbooks_ledger',
      'calculation_type' => 'bs_balance'
    }
  end

  def values_config(second_arg_id:, item_id:) # rubocop:disable Metrics/MethodLength
    {
      'percentage' => {
        'value' => {
          'expression' => {
            'operator' => '%',
            'arg1' => {
              'item_id' => item_id
            },
            'arg2' => {
              'item_id' => second_arg_id
            }
          }
        }
      }
    }
  end
end
