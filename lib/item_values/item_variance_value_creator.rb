# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=variance)
  class ItemVarianceValueCreator < BaseItemValueCreator
    def call
      generate_variance_column_value
    end

    private

    def generate_variance_column_value # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      current_actual_column = @report.detect_column(type: Column::TYPE_ACTUAL, range: @column.range, year: Column::YEAR_CURRENT)
      # @column.year || Column::YEAR_PRIOR in below line is for Advanced Balance Sheet report.
      # In this report, Variance value is calculated between PTD column and PP column.
      # So when variance column is defined in template file, "previous_period" as year field is added.
      prior_actual_column = @report.detect_column(type: Column::TYPE_ACTUAL, range: @column.range, year: @column.year || Column::YEAR_PRIOR)
      current_actual_item_value = @report_data.item_values.detect do |item_value|
        item_value.item_id == @item.id.to_s && item_value.column_id == current_actual_column.id.to_s
      end
      prior_actual_item_value = @report_data.item_values.detect do |item_value|
        item_value.item_id == @item.id.to_s && item_value.column_id == prior_actual_column.id.to_s
      end
      return if current_actual_item_value&.value.nil? || prior_actual_item_value&.value.nil?

      item_amount = current_actual_item_value.value - prior_actual_item_value.value
      item_value = generate_item_value(item: @item, column: @column, item_amount: item_amount)

      @item.mapped_item_accounts.each do |item_account|
        business_chart_of_account = @all_business_chart_of_accounts.detect { |category| category.chart_of_account_id == item_account.chart_of_account_id }
        next if business_chart_of_account.nil?

        accounting_class = @accounting_classes.detect { |business_accounting_class| business_accounting_class.id == item_account.accounting_class_id }
        next if item_account.accounting_class_id.present? && accounting_class.nil?

        generate_item_account_value(item_value: item_value, current_actual_item_value: current_actual_item_value,
                                    prior_actual_item_value: prior_actual_item_value, item_account: item_account)
      end
      item_value.column_type = prior_actual_item_value.column_type
      item_value
    end

    def generate_item_account_value(item_value:, current_actual_item_value:, prior_actual_item_value:, item_account:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      current_account_value = current_actual_item_value.item_account_values.detect do |item_account_value|
        item_account_value.chart_of_account_id == item_account.chart_of_account_id && item_account_value.accounting_class_id == item_account.accounting_class_id
      end
      return if current_account_value.nil?

      prior_account_value = prior_actual_item_value.item_account_values.detect do |item_account_value|
        item_account_value.chart_of_account_id == item_account.chart_of_account_id && item_account_value.accounting_class_id == item_account.accounting_class_id
      end
      return if prior_account_value.nil?

      item_account_value_amount = current_account_value.value - prior_account_value.value
      item_value.item_account_values.new(chart_of_account_id: item_account.chart_of_account_id,
                                         accounting_class_id: item_account.accounting_class_id,
                                         name: current_account_value.name,
                                         value: item_account_value_amount.round(2))
    end
  end
end
