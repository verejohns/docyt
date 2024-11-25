# frozen_string_literal: true

module ItemValues
  class ItemValueCreator
    def initialize( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
      report_data:,
      budgets:, standard_metrics:,
      dependent_report_datas:,
      previous_month_report_data:,
      previous_year_report_data:,
      january_report_data_of_current_year:,
      all_business_chart_of_accounts:,
      all_business_vendors:,
      accounting_classes:,
      qbo_ledgers:
    )
      @report_data = report_data
      @report = report_data.report
      @budgets = budgets
      @standard_metrics = standard_metrics
      @dependent_report_datas = dependent_report_datas
      @previous_month_report_data = previous_month_report_data
      @previous_year_report_data = previous_year_report_data
      @january_report_data_of_current_year = january_report_data_of_current_year
      @all_business_chart_of_accounts = all_business_chart_of_accounts
      @all_business_vendors = all_business_vendors
      @accounting_classes = accounting_classes
      @qbo_ledgers = qbo_ledgers
    end

    def call(column:, item:) # rubocop:disable Metrics/MethodLength
      return nil unless can_create_item_value?(item: item, column: column)

      item_value_creator_class = creator_class(item: item, column: column)
      creator_instance = item_value_creator_class.new(
        report_data: @report_data, item: item, column: column,
        budgets: @budgets, standard_metrics: @standard_metrics,
        dependent_report_datas: @dependent_report_datas,
        previous_month_report_data: @previous_month_report_data,
        previous_year_report_data: @previous_year_report_data,
        january_report_data_of_current_year: @january_report_data_of_current_year,
        all_business_chart_of_accounts: @all_business_chart_of_accounts,
        all_business_vendors: @all_business_vendors,
        accounting_classes: @accounting_classes,
        qbo_ledgers: @qbo_ledgers
      )
      creator_instance.call
    end

    private

    def creator_class(item:, column:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      if @report_data.report.departmental_report?
        case column.type
        when Column::TYPE_ACTUAL
          if item.totals
            ItemActualsValue::ItemTotalActualsValueCreator
          else
            ItemDepartmentalValueCreator
          end
        when Column::TYPE_BUDGET_ACTUAL
          ItemDepartmentBudgetActualsValueCreator
        when Column::TYPE_BUDGET_PERCENTAGE
          ItemDepartmentBudgetPercentageValueCreator
        when Column::TYPE_BUDGET_VARIANCE
          ItemBudgetVarianceValueCreator
        end
      # The variance column has "previous_period" as year field in Advanced Balance Sheet report.
      # But ItemPriorValueCreator is for only actual, percentage type.
      # So the case that the type is variance should be excepted in below case.
      elsif (column.year == Column::YEAR_PRIOR || column.year == Column::PREVIOUS_PERIOD) && column.type != Column::TYPE_VARIANCE
        ItemPriorValueCreator
      else
        case column.type
        when Column::TYPE_ACTUAL, Column::TYPE_GROSS_ACTUAL
          ItemActualsValue::ItemActualsValueCreator
        when Column::TYPE_PERCENTAGE, Column::TYPE_GROSS_PERCENTAGE, Column::TYPE_VARIANCE_PERCENTAGE
          ItemPercentageValueCreator
        when Column::TYPE_VARIANCE
          ItemVarianceValueCreator
        when Column::TYPE_BUDGET_ACTUAL
          ItemBudgetActualsValueCreator
        when Column::TYPE_BUDGET_PERCENTAGE
          ItemBudgetPercentageValueCreator
        when Column::TYPE_BUDGET_VARIANCE
          ItemBudgetVarianceValueCreator
        end
      end
    end

    def can_create_item_value?(item:, column:)
      return false if item.type_config.blank? && !item.totals
      return false if column.year == Column::YEAR_PRIOR && @previous_year_report_data.nil?
      return false if column.year == Column::PREVIOUS_PERIOD && @previous_month_report_data.nil?

      true
    end
  end
end
