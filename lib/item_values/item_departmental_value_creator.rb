# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the departmental report
  class ItemDepartmentalValueCreator < BaseItemValueCreator
    def call
      generate_department_item_value
    end

    private

    def generate_department_item_value
      item_amount = department_item_value_amount.round(2)
      generate_item_value(
        item: @item, column: @column, item_amount: item_amount,
        accumulated_value_amount: accumulated_value_from_previous_report_data(current_value: item_amount)
      )
    end

    def department_item_value_amount # rubocop:disable Metrics/MethodLength
      item_account = @item.item_accounts.first
      accounting_class = @accounting_classes.detect { |business_accounting_class| business_accounting_class.id == item_account&.accounting_class_id }
      return 0.00 if item_account&.accounting_class_id.present? && accounting_class.nil?

      case departmental_item_type
      when Item::REVENUE
        revenue_item_value_amount(accounting_class: accounting_class)
      when Item::EXPENSES
        expenses_item_value_amount(accounting_class: accounting_class)
      else
        revenue_item_value_amount(accounting_class: accounting_class) - expenses_item_value_amount(accounting_class: accounting_class)
      end
    end

    def revenue_item_value_amount(accounting_class:)
      return 0.00 if @qbo_ledgers[Quickbooks::RevenueGeneralLedger].nil?

      line_item_details = @qbo_ledgers[Quickbooks::RevenueGeneralLedger].line_item_details.select { |lid| lid.accounting_class_qbo_id == accounting_class.external_id }
      line_item_details.sum(&:amount) || 0.00
    end

    def expenses_item_value_amount(accounting_class:)
      return 0.00 if @qbo_ledgers[Quickbooks::ExpensesGeneralLedger].nil?

      line_item_details = @qbo_ledgers[Quickbooks::ExpensesGeneralLedger].line_item_details.select { |lid| lid.accounting_class_qbo_id == accounting_class.external_id }
      line_item_details.sum(&:amount) || 0.00
    end
  end
end
