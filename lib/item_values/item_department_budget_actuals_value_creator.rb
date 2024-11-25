# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=budget_actual) of department report
  class ItemDepartmentBudgetActualsValueCreator < BaseItemValueCreator
    def call
      if @item.totals
        generate_total_value
      else
        generate_actual_column_value
      end
    end

    private

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

    def generate_actual_column_value
      budget_values = generate_budget_values
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def generate_budget_values # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      item_account = @item.item_accounts.first
      accounting_class = @accounting_classes.detect { |ac| ac.id == item_account&.accounting_class_id }

      case departmental_item_type
      when Item::REVENUE, Item::EXPENSES
        department_budget_values(accounting_class: accounting_class, item_type: departmental_item_type)
      else
        revenue_item_itendifier = @item.identifier.gsub(Item::PROFIT, Item::REVENUE)
        expenses_item_itendifier = @item.identifier.gsub(Item::PROFIT, Item::EXPENSES)
        revenue_item_value = actual_value_by_identifier(identifier: revenue_item_itendifier, column: @column)
        expenses_item_value = actual_value_by_identifier(identifier: expenses_item_itendifier, column: @column)
        @budgets.map do |budget|
          revenue_value = revenue_item_value.budget_values.detect { |rv| rv[:budget_id] == budget.id.to_s }[:value]
          expenses_value = expenses_item_value.budget_values.detect { |ev| ev[:budget_id] == budget.id.to_s }[:value]
          { budget_id: budget.id.to_s, value: revenue_value - expenses_value }
        end
      end
    end

    def department_budget_values(accounting_class:, item_type:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      acc_types = item_type == Item::REVENUE ? REVENUE_CHART_OF_ACCOUNT_TYPES : EXPENSES_CHART_OF_ACCOUNT_TYPES
      chart_of_accounts = @all_business_chart_of_accounts.select { |bcoa| acc_types.include?(bcoa.acc_type) }
      chart_of_account_ids = chart_of_accounts.map(&:chart_of_account_id)

      @budgets.map do |budget|
        budget_items = budget.actual_budget_items.where(accounting_class_id: accounting_class.id, :chart_of_account_id.in => chart_of_account_ids)
        budget_item_values = budget_items.map do |budget_item|
          budget_item_value = budget_item.budget_item_values.detect { |biv| biv.month == @report_data.start_date.month }
          budget_item_value&.value || 0.0
        end
        { budget_id: budget.id.to_s, value: budget_item_values.sum }
      end
    end
  end
end
