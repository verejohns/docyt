# frozen_string_literal: true

class ItemValue
  include Mongoid::Document

  field :value, type: Float # This value can be nil, it means no data for metric item.
  field :column_type, type: String
  field :item_id, type: String
  field :column_id, type: String
  field :item_identifier, type: String
  field :dependency_accumulated_value, type: Float # This field is only used for multi business report percentage calculation.
  field :accumulated_value, type: Float
  field :budget_values, type: Array, default: []

  embedded_in :report_data, class_name: 'ReportData'
  embeds_many :item_account_values, class_name: 'ItemAccountValue'

  def date_range
    column = report_data.report.columns.find(column_id)
    start_date = report_data.start_date - date_delta(column: column)
    end_date = case report_data.period_type
               when ReportData::PERIOD_MONTHLY
                 Date.new(start_date.year, start_date.month, -1)
               when ReportData::PERIOD_ANNUALLY
                 Date.new(start_date.year, 12, -1)
               end
    start_date = start_date.at_beginning_of_year if column.range == Column::RANGE_YTD
    (start_date..end_date)
  end

  def date_delta(column:) # rubocop:disable Metrics/MethodLength
    case column.year
    when Column::YEAR_PRIOR
      1.year
    when Column::PREVIOUS_PERIOD
      case report_data.period_type
      when ReportData::PERIOD_MONTHLY
        1.month
      when ReportData::PERIOD_ANNUALLY
        1.year
      else
        0
      end
    else
      0
    end
  end

  def formatted_value
    return nil if value.nil?

    formatted_amount(amount: value)
  end

  def formatted_amount(amount:)
    result = amount.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    case column_type
    when Column::TYPE_PERCENTAGE
      "#{result}%"
    when Column::TYPE_VARIANCE
      result
    else
      "$#{result}"
    end
  end

  def generate_column_type
    report = report_data.report
    item = report.find_item_by_id(id: item_id)
    column = report.columns.find(column_id)
    generate_column_type_with_infos(item: item, column: column)
  end

  def generate_column_type_with_infos(item:, column:) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    stats_formula = item.values_config[Column::TYPE_ACTUAL] if item.values_config.present?
    if column.type == Column::TYPE_PERCENTAGE || column.type == Column::TYPE_BUDGET_PERCENTAGE || column.type == Column::TYPE_GROSS_PERCENTAGE || column.type == Column::TYPE_VARIANCE_PERCENTAGE # rubocop:disable Layout/LineLength
      self.column_type = Column::TYPE_PERCENTAGE
    elsif stats_formula.present? && stats_formula['value'].present? && stats_formula['value']['expression'].present? && stats_formula['value']['expression']['operator'] == '%'
      self.column_type = Column::TYPE_PERCENTAGE
    elsif item.type_config.present? && (item.type_config['name'] == Item::TYPE_METRIC || item.type_config['name'] == Item::TYPE_REFERENCE)
      self.column_type = Column::TYPE_VARIANCE
    else
      self.column_type = Column::TYPE_ACTUAL
    end
  end
end
