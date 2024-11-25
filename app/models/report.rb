# frozen_string_literal: true

class Report # rubocop:disable Metrics/ClassLength
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  include DocytLib::Async::Publisher

  UPDATE_STATE_QUEUED = 'queued'
  UPDATE_STATE_STARTED = 'started'
  UPDATE_STATE_FINISHED = 'finished'
  UPDATE_STATE_FAILED = 'failed'

  PERIOD_DAILY = 'daily'
  PERIOD_MONTHLY = 'monthly'

  DEPARTMENT_REPORT = 'departmental_report'
  REVENUE_REPORT = 'revenue_report'
  VENDOR_REPORT = 'vendor_report'
  UPS_REPORTS = %w[owners_report store_managers_report].freeze
  STORE_MANAGERS_REPORT = 'store_managers_report'
  REVENUE_ACCOUNTING_REPORT = 'revenue_accounting_report'
  UPS_ADVANCED_BALANCE_SHEET_REPORT = 'ups_advanced_balance_sheet'
  UPS_ADVANCED_OWNERS_REPORT = 'owners_report'

  ERROR_MSG_QBO_NOT_CONNECTED = 'QuickBooks is not connected.'

  field :docyt_service_id, type: Integer # This will be removed later
  field :template_id, type: String
  field :name, type: String
  field :updated_at, type: DateTime
  field :missing_transactions_calculation_disabled, type: Boolean, default: true
  field :dependent_template_ids, type: Array
  field :update_state, type: String
  field :error_msg, type: String
  field :view_by_options, type: Array
  field :enabled_budget_compare, type: Boolean, default: true
  field :total_column_visible, type: Boolean, default: true
  field :accounting_class_check_disabled, type: Boolean, default: false
  field :edit_mapping_disabled, type: Boolean, default: false
  field :accepted_accounting_class_ids, type: Array, default: []
  field :accepted_account_types, type: Array, default: []
  field :enabled_blank_value_for_metric, type: Boolean, default: false

  validates :template_id, presence: true, uniqueness: { scope: :report_service_id }
  validates :name, presence: true

  embeds_many :items, class_name: 'Item'
  embeds_many :columns, class_name: 'Column'
  embeds_many :report_users, class_name: 'ReportUser'

  belongs_to :report_service, class_name: 'ReportService', inverse_of: :reports
  has_many :report_datas, class_name: 'ReportData', inverse_of: :report, dependent: :delete_all
  has_many :unincluded_line_item_details, class_name: 'Quickbooks::UnincludedLineItemDetail', inverse_of: :report, dependent: :delete_all

  index({ report_service_id: 1, template_id: 1 }, { unique: true })
  index 'items.order' => 1
  index 'items.item_accounts.chart_of_account_id' => 1

  def refill_report
    if template_id == Report::DEPARTMENT_REPORT
      ReportFactory.refill_report(report: self)
    else
      factory_class = report_template.factory_class
      factory_class.refill_report(report: self)
    end
  end

  def linked_chart_of_account_ids
    chart_of_account_ids = []
    items.each do |item|
      chart_of_account_ids += item_chart_of_account_ids(item: item)
    end
    chart_of_account_ids.uniq
  end

  def refresh_all_report_datas(priority = nil)
    publish(events.refresh_report_request(report_id: id.to_s), priority: priority)
  end

  def find_item_by_identifier(identifier:)
    child_item = items.detect { |item| item.identifier == identifier }
    return child_item if child_item.present?

    items.each do |parent_item|
      item = parent_item.find_child_by_identifier(identifier: identifier)
      return item if item.present?
    end
    nil
  end

  def find_item_by_id(id:)
    child_item = items.detect { |item| item._id.to_s == id }
    return child_item if child_item.present?

    items.each do |parent_item|
      item = parent_item.find_child_by_id(id)
      return item if item.present?
    end
    nil
  end

  def find_item_value_by_id(id)
    report_datas.each do |report_data|
      item_value = report_data.item_values.detect { |iv| iv._id.to_s == id }
      return item_value if item_value.present?
    end
    nil
  end

  def all_item_accounts
    items.map(&:all_item_accounts).flatten
  end

  def departmental_report?
    template_id == DEPARTMENT_REPORT
  end

  def revenue_accounting_report?
    template_id == REVENUE_ACCOUNTING_REPORT
  end

  def revenue_report?
    template_id == REVENUE_REPORT
  end

  def vendor_report?
    template_id == VENDOR_REPORT
  end

  def detect_column(type:, range:, year: nil)
    if year.present?
      columns.detect { |column| column.type == type && column.range == range && column.year == year }
    else
      columns.detect { |column| column.type == type && column.range == range }
    end
  end

  def dependent_reports
    return [] if dependent_template_ids.blank?

    report_service.reports.where(template_id: { '$in': dependent_template_ids })
  end

  def january_report_data_required?
    return false if columns.detect { |column| column.range == Column::RANGE_YTD }.nil?

    items.each do |parent_item|
      return true if parent_item.include_bs_prior_day_item?
    end
    false
  end

  def report_items
    all_items = []
    items.each do |parent_item|
      all_items += all_child_items(item: parent_item)
    end
    all_items
  end

  def all_child_items(item:)
    items = []
    if item.child_items.count.positive?
      item.child_items.each do |child_item|
        items += all_child_items(item: child_item)
      end
    end
    items << item
    items
  end

  def enabled_default_mapping
    items.each do |item|
      return true if default_accounts_fieldset?(item: item)
    end
    false
  end

  def report_template
    @report_template ||= ReportTemplate.find_by(template_id: template_id)
  end

  private

  def item_chart_of_account_ids(item:)
    chart_of_account_ids = []
    if item.child_items.count.positive?
      item.child_items.each do |child_item|
        chart_of_account_ids += item_chart_of_account_ids(item: child_item)
      end
    else
      chart_of_account_ids = item.mapped_item_accounts.pluck(:chart_of_account_id)
    end
    chart_of_account_ids.uniq
  end

  def default_accounts_fieldset?(item:)
    exist = false
    if item.child_items.count.positive?
      item.child_items.each do |child_item|
        exist = true if default_accounts_fieldset?(item: child_item)
      end
    else
      exist = item.type_config.present? && item.type_config['default_accounts'].present? && item.type_config['default_accounts'].length.positive?
    end
    exist
  end
end
