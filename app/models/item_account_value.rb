# frozen_string_literal: true

class ItemAccountValue
  include Mongoid::Document

  field :chart_of_account_id, type: Integer
  field :accounting_class_id, type: Integer
  field :name, type: String, default: ''
  field :value, type: Float, default: 0.0

  validates :chart_of_account_id, presence: true
  validates :value, presence: true

  embedded_in :item_value, class_name: 'ItemValue'

  def line_item_details
    line_item_details_query = Quickbooks::LineItemDetailsQuery.new(
      report: item_value.report_data.report,
      item: item_value.report_data.report.find_item_by_identifier(identifier: item_value.item_identifier),
      params: { chart_of_account_id: chart_of_account_id, accounting_class_id: accounting_class_id }
    )
    date_range = item_value.date_range
    line_item_details_query.by_period(start_date: date_range.first, end_date: date_range.last, include_total: true)
  end
end
