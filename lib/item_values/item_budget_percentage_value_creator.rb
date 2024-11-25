# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=budget_percentage)
  class ItemBudgetPercentageValueCreator < BaseItemValueCreator
    def call
      generate_percentage_column_value
    end

    private

    def generate_percentage_column_value # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      expression = item_expression(item: @item, target_column_type: Column::TYPE_PERCENTAGE)
      return if expression.blank?

      source_column = @report.columns.find_by(type: Column::TYPE_BUDGET_ACTUAL, range: @column.range, year: @column.year)
      arg_item_value1 = actual_value_by_identifier(identifier: expression['arg1']['item_id'], column: source_column)
      arg_item_value2 = actual_value_by_identifier(identifier: expression['arg2']['item_id'], column: source_column)
      budget_values = @budgets.map do |budget|
        arg_budget_value1 = arg_item_value1.budget_values.detect { |bv| bv[:budget_id] == budget.id.to_s } || {}
        arg_budget_value2 = arg_item_value2.budget_values.detect { |bv| bv[:budget_id] == budget.id.to_s } || {}
        { budget_id: budget.id.to_s, value: calculate_value_with_operator(arg_budget_value1[:value], arg_budget_value2[:value], expression['operator']) }
      end
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end
  end
end
