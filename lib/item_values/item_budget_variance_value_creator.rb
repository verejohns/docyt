# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=budget_variance)
  class ItemBudgetVarianceValueCreator < BaseItemValueCreator
    def call
      generate_variance_column_value
    end

    private

    def generate_variance_column_value # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      actual_column = @report.columns.find_by(type: Column::TYPE_ACTUAL, range: @column.range, year: Column::YEAR_CURRENT)
      budget_actual_column = @report.columns.find_by(type: Column::TYPE_BUDGET_ACTUAL, range: @column.range, year: Column::YEAR_CURRENT)
      actual_item_value = @report_data.item_values.detect do |item_value|
        item_value.item_id == @item.id.to_s && item_value.column_id == actual_column.id.to_s
      end
      budget_actual_item_value = @report_data.item_values.detect do |item_value|
        item_value.item_id == @item.id.to_s && item_value.column_id == budget_actual_column.id.to_s
      end

      budget_values = budget_actual_item_value.budget_values.map do |budget_value|
        { budget_id: budget_value[:budget_id], value: actual_item_value[:value] - budget_value[:value] }
      end
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end
  end
end
