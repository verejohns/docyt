# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=budget_actual)
  class ItemBudgetActualsValueCreator < BaseItemValueCreator
    def call
      if @item.totals
        generate_total_value
      elsif @item.values_config.present? && @item.values_config[Column::TYPE_ACTUAL].present?
        generate_stat_column_value
      elsif @column.range == Column::RANGE_CURRENT
        generate_for_current_period
      else
        generate_for_ytd
      end
    end

    private

    def generate_for_current_period # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
      metric_type = (@item.type_config.present? && @item.type_config['metric'].present? && @item.type_config['metric']['name']) || nil
      standard_metric = @standard_metrics.detect { |sm| sm.type == metric_type }
      item_accounts = @item.mapped_item_accounts.map { |ia| { chart_of_account_id: ia.chart_of_account_id, accounting_class_id: ia.accounting_class_id } }
      item_accounts << { chart_of_account_id: nil, accounting_class_id: nil, standard_metric_id: standard_metric.id.to_s } if standard_metric.present?
      budget_values = @budgets.map do |budget|
        budget_item_values = item_accounts.map do |ia|
          budget_item = budget.actual_budget_items.find_by(
            chart_of_account_id: ia[:chart_of_account_id],
            accounting_class_id: ia[:accounting_class_id],
            standard_metric_id: ia[:standard_metric_id]
          )
          budget_item_value = budget_item.budget_item_values.detect { |biv| biv.month == @report_data.start_date.month } if budget_item.present?
          budget_item_value&.value || 0.0
        end
        { budget_id: budget.id.to_s, value: budget_item_values.sum }
      end
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def generate_for_ytd # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      current_budget_actual_column = @report.detect_column(type: @column.type, range: Column::RANGE_CURRENT, year: @column.year)
      current_budget_actual_column_item_value = @report_data.item_values.detect do |item_value|
        item_value.item_id == @item.id.to_s && item_value.column_id == current_budget_actual_column.id.to_s
      end
      previous_month_ytd_item_value = nil
      if @report_data.start_date.month > 1 && @previous_month_report_data.present?
        previous_month_ytd_item_value = @previous_month_report_data.item_values.detect do |item_value|
          item_value.item_id == @item.id.to_s && item_value.column_id == @column.id.to_s
        end
      end
      ytd_budget_values = current_budget_actual_column_item_value.budget_values.map do |actual_budget_value|
        previous_ytd_budget_value = 0
        if previous_month_ytd_item_value.present?
          previous_month_ytd_budget_value = previous_month_ytd_item_value.budget_values.detect do |previous_budget_value|
            previous_budget_value[:budget_id] == actual_budget_value[:budget_id]
          end
          previous_ytd_budget_value = previous_month_ytd_budget_value[:value]
        end
        { budget_id: actual_budget_value[:budget_id], value: previous_ytd_budget_value + actual_budget_value[:value] }
      end
      generate_item_value(item: @item, column: @column, budget_values: ytd_budget_values)
    end

    def generate_total_value # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      child_items = @item.parent_item.child_items.reject { |child_item| child_item.id == @item.id }
      budget_values = @budgets.map do |budget|
        budget_item_values = child_items.map do |child_item|
          child_total_item = if child_item.child_items.present?
                               child_item.total_item
                             else
                               child_item
                             end
          item_value = actual_value_by_identifier(identifier: child_total_item.identifier, column: @column)
          budget_value = item_value.budget_values.detect { |bv| bv[:budget_id] == budget.id.to_s }
          value = budget_value.present? ? budget_value[:value] : 0.0
          child_total_item.negative_for_total ? -value : value
        end
        { budget_id: budget.id.to_s, value: budget_item_values.sum + parent_item_value(budget: budget) }
      end
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def parent_item_value(budget:)
      parent_item = @item.parent_item
      return 0.0 if parent_item.type_config.blank?

      parent_item_value = actual_value_by_identifier(identifier: parent_item.identifier, column: @column)
      budget_value = parent_item_value.budget_values.detect { |bv| bv[:budget_id] == budget.id.to_s }
      budget_value.present? ? budget_value[:value] : 0.0
    end

    def generate_stat_column_value # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      budget_values = []
      expression = item_expression(item: @item, target_column_type: Column::TYPE_ACTUAL)
      if expression.present?
        if expression['operator'] == OPERATOR_SUM
          budget_values = @budgets.map do |budget|
            budget_item_value_amounts = sub_item_value_amounts(expression['arg']['sub_items'], budget)
            { budget_id: budget.id.to_s, value: budget_item_value_amounts.sum }
          end
        else
          arg_item_value1 = actual_value_by_identifier(identifier: expression['arg1']['item_id'], column: @column)
          arg_item_value2 = actual_value_by_identifier(identifier: expression['arg2']['item_id'], column: @column)
          budget_values = @budgets.map do |budget|
            arg_budget_value1 = arg_item_value1.budget_values.detect { |bv| bv[:budget_id] == budget.id.to_s } || {}
            arg_budget_value2 = arg_item_value2.budget_values.detect { |bv| bv[:budget_id] == budget.id.to_s } || {}
            { budget_id: budget.id.to_s, value: calculate_value_with_operator(arg_budget_value1[:value], arg_budget_value2[:value], expression['operator']) }
          end
        end
      end
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def sub_item_value_amounts(sub_items, budget)
      sub_items.map do |sub_item|
        item_value = actual_value_by_identifier(identifier: sub_item['id'], column: @column)
        budget_value = item_value.budget_values.detect { |bv| bv[:budget_id] == budget.id.to_s }
        value = budget_value.present? ? budget_value[:value] : 0.0
        sub_item['negative'] ? -value : value
      end
    end
  end
end
