# frozen_string_literal: true

class ReportDatasBaseQuery
  protected

  def initialize() end

  def recalculate_for_total_report_data(report_data:, column:, report_items:)
    report_items.each do |item|
      recalculate_for_special_item(report_data: report_data, item: item, column: column)
    end
  end

  def recalculate_for_special_item(report_data:, item:, column:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    stats_formula = item.values_config[column.type] if item.values_config.present?
    return if stats_formula.blank? || stats_formula['value'].blank? || stats_formula['value']['expression'].blank?

    expression = stats_formula['value']['expression']
    return if expression['operator'].blank? || expression['arg1'].blank? || expression['arg2'].blank?

    if (expression['arg1']['item_id'].include?('/') || expression['arg2']['item_id'].include?('/')) && column.type == Column::TYPE_PERCENTAGE
      recalculate_percentage_value_with_dependency(total_report_data: report_data, item: item, column: column)
    elsif (expression['arg1']['item_id'].include?('/') || expression['arg2']['item_id'].include?('/')) && column.type == Column::TYPE_GROSS_PERCENTAGE
      recalculate_percentage_value_with_dependency(total_report_data: report_data, item: item, column: column)
    elsif expression['operator'] == '%' || expression['operator'] == '/'
      recalculate_item_value_for_total_report(report_data: report_data, expression: expression, item: item, column: column)
    end
  end

  def recalculate_item_value_for_total_report(report_data:, expression:, item:, column:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
    item_amount = 0.0
    source_column = report_data.report.columns.detect do |cl|
      cl.type == Column::TYPE_ACTUAL && cl.range == column.range && cl.year == column.year
    end
    arg_item_value1 = actual_value_by_identifier(report_data: report_data, identifier: expression['arg1']['item_id'], column: source_column)
    arg_item_value2 = actual_value_by_identifier(report_data: report_data, identifier: expression['arg2']['item_id'], column: source_column)
    case expression['operator']
    when '/'
      item_amount = arg_item_value1 / arg_item_value2 if arg_item_value2.abs.positive?
    when '%'
      item_amount = arg_item_value1 / arg_item_value2 * 100.0 if arg_item_value2.abs.positive?
    end
    update_item_value(report_data: report_data, item: item, column: column, item_amount: item_amount)
  end

  def update_item_value(report_data:, item:, column:, item_amount:)
    item_value = report_data.item_values.detect { |iv| iv.item_id == item.id.to_s && iv.column_id == column.id.to_s }
    if item_value.nil?
      total_item_value = report_data.item_values.new(item_id: item.id.to_s, column_id: column.id.to_s, value: item_amount.round(2), item_identifier: item.identifier)
      total_item_value.generate_column_type_with_infos(item: item, column: column)
    else
      item_value.value = item_amount.round(2)
    end
  end

  def recalculate_percentage_value_with_dependency(total_report_data:, item:, column:)
    item_amount = 0.0
    actual_value = total_report_data.item_values.detect { |iv| iv.item_id == item.id.to_s && iv.column_id == @data_column.id.to_s }
    if actual_value.present? && actual_value.dependency_accumulated_value.present? && actual_value.dependency_accumulated_value.abs.positive?
      item_amount = actual_value.value / actual_value.dependency_accumulated_value * 100.0
    end
    update_item_value(report_data: total_report_data, item: item, column: column, item_amount: item_amount)
  end

  def actual_value_by_identifier(report_data:, identifier:, column:)
    item_value = report_data.item_values.detect { |iv| iv.item_identifier == identifier && iv.column_id == column.id.to_s }
    item_value&.value || 0.0
  end

  def item_value_from_report_data(report_data:, item:, column:)
    report_data.item_values.detect { |item_value| item_value.item_id == item.id.to_s && item_value.column_id == column.id.to_s }
  end
end
