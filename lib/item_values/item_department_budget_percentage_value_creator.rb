# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=budget_percentage) of department report
  class ItemDepartmentBudgetPercentageValueCreator < BaseItemValueCreator
    def call
      generate_percentage_column_value
    end

    private

    def generate_percentage_column_value # rubocop:disable Metrics/AbcSize
      budget_actual_column = @report.columns.find_by(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      total_item_value = actual_value_by_identifier(identifier: "total_#{departmental_item_type}", column: budget_actual_column)
      budget_actual_item_value = @report_data.item_values.detect do |item_value|
        item_value.item_id == @item.id.to_s && item_value.column_id == budget_actual_column.id.to_s
      end

      budget_values = budget_actual_item_value.budget_values.map do |budget_value|
        total_budget_actual_value = total_item_value.budget_values.detect { |bv| bv[:budget_id] == budget_value[:budget_id] }[:value]
        { budget_id: budget_value[:budget_id], value: calculate_value_with_operator(budget_value[:value], total_budget_actual_value, '%') }
      end
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end
  end
end
