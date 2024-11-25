# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=[actual, percentage], year=prior)
  class ItemPriorValueCreator < BaseItemValueCreator
    def call
      generate_prior_column_value
    end

    private

    def generate_prior_column_value # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      return if previous_report_data.nil?

      current_data_column = @report.columns.detect do |column|
        column.type == @column.type && column.range == @column.range && column.year == Column::YEAR_CURRENT
      end
      prev_item_value = previous_report_data.item_values.detect do |item_value|
        item_value.item_id == @item.id.to_s && item_value.column_id == current_data_column.id.to_s
      end
      return if prev_item_value.nil?

      new_item_value = generate_item_value(item: @item, column: @column, item_amount: prev_item_value.value)
      new_item_value.column_type = prev_item_value.column_type
      copy_account_values(src_item_values: [prev_item_value], dst_item_value: new_item_value)
    end

    def previous_report_data
      case @column.year
      when Column::YEAR_PRIOR
        @previous_year_report_data
      when Column::PREVIOUS_PERIOD
        @previous_month_report_data
      end
    end
  end
end
