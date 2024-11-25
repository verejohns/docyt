# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemGeneralLedgerActualsValueCreator < BaseItemActualsValueCreator # rubocop:disable Metrics/ClassLength
      def call
        generate_from_general_ledger
      end

      private

      def generate_from_general_ledger # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
        item_value_amount = 0.00
        item_value = generate_item_value(item: @item, column: @column, item_amount: 0.0)

        @item.mapped_item_accounts.each do |item_account|
          business_chart_of_account = @all_business_chart_of_accounts.detect { |category| category.chart_of_account_id == item_account.chart_of_account_id }
          next if business_chart_of_account.nil?

          accounting_class = @accounting_classes.detect { |business_accounting_class| business_accounting_class.id == item_account.accounting_class_id }
          next if item_account.accounting_class_id.present? && accounting_class.nil?

          item_account_value_amount = generate_item_account_value(item_value: item_value, item_account: item_account,
                                                                  business_chart_of_account: business_chart_of_account, accounting_class: accounting_class)
          item_value_amount += item_account_value_amount
        end
        value = @item.negative ? -item_value_amount : item_value_amount
        item_value.value = value.round(2)
        item_value.accumulated_value = accumulated_value_from_previous_report_data(current_value: value)
        item_value.dependency_accumulated_value = calculate_dependency_accumulated_value
        item_value
      end

      def generate_item_account_value(item_value:, item_account:, business_chart_of_account:, accounting_class:) # rubocop:disable Metrics/MethodLength
        case @item.type_config[Item::CALCULATION_TYPE_CONFIG]
        when Item::BS_BALANCE_CALCULATION_TYPE
          generate_item_account_value_with(item_value: item_value, item_account: item_account, qbo_ledger: current_balance_sheet,
                                           business_chart_of_account: business_chart_of_account, accounting_class: accounting_class)
        when Item::BS_PRIOR_DAY_CALCULATION_TYPE
          generate_item_account_value_with(item_value: item_value, item_account: item_account, qbo_ledger: prior_balance_sheet,
                                           business_chart_of_account: business_chart_of_account, accounting_class: accounting_class)
        when Item::BS_NET_CHANGE_CALCULATION_TYPE # Only monthly
          generate_net_change_item_account_value_with(item_value: item_value, item_account: item_account, qbo_ledgers: @qbo_ledgers[Quickbooks::BalanceSheetGeneralLedger],
                                                      business_chart_of_account: business_chart_of_account, accounting_class: accounting_class)
        when Item::BANK_GENERAL_LEDGER_CALCULATION_TYPE
          generate_item_account_value_with_bank_ledger(
            item_value: item_value, item_account: item_account,
            qbo_ledger: @qbo_ledgers[Quickbooks::BankGeneralLedger], common_ledger: @qbo_ledgers[Quickbooks::CommonGeneralLedger],
            business_chart_of_account: business_chart_of_account, accounting_class: accounting_class
          )
        when Item::TAX_COLLECTED_VALUE_CALCULATION_TYPE
          generate_item_account_value_for_tax_ledger(
            item_value: item_value, item_account: item_account,
            bank_ledger: @qbo_ledgers[Quickbooks::BankGeneralLedger],
            ap_ledger: @qbo_ledgers[Quickbooks::AccountsPayableGeneralLedger],
            common_ledger: @qbo_ledgers[Quickbooks::CommonGeneralLedger],
            business_chart_of_account: business_chart_of_account, accounting_class: accounting_class
          )
        else
          generate_item_account_value_with(item_value: item_value, item_account: item_account, qbo_ledger: @qbo_ledgers[Quickbooks::CommonGeneralLedger],
                                           business_chart_of_account: business_chart_of_account, accounting_class: accounting_class)
        end
      end

      def current_balance_sheet
        if @report_data.daily? && @column.range == Column::RANGE_MTD
          @qbo_ledgers[Quickbooks::BalanceSheetGeneralLedger][:current_mtd]
        else
          @qbo_ledgers[Quickbooks::BalanceSheetGeneralLedger][:current_period]
        end
      end

      def prior_balance_sheet
        if @report_data.daily? && @column.range == Column::RANGE_MTD
          @qbo_ledgers[Quickbooks::BalanceSheetGeneralLedger][:previous_mtd]
        else
          @qbo_ledgers[Quickbooks::BalanceSheetGeneralLedger][:previous_period]
        end
      end

      def generate_item_account_value_with(item_value:, item_account:, qbo_ledger:, business_chart_of_account:, accounting_class:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
        item_account_value_amount = 0.00
        if qbo_ledger.present?
          qbo_ledger_line_item_details = qbo_ledger.line_item_details.select do |lid|
            lid.chart_of_account_qbo_id == business_chart_of_account.qbo_id
          end
          if qbo_ledger.instance_of?(Quickbooks::CommonGeneralLedger)
            qbo_ledger_line_item_details.select! do |lid|
              transaction_date = lid.transaction_date.to_date
              (transaction_date >= start_date_by_column) && (transaction_date <= @report_data.end_date)
            end
            qbo_ledger_line_item_details.select! { |lid| lid.amount >= 0.00 } if @item.type_config[Item::CALCULATION_TYPE_CONFIG] == Item::DEBITS_ONLY_CALCULATION_TYPE
            qbo_ledger_line_item_details.select! { |lid| lid.amount < 0.00 } if @item.type_config[Item::CALCULATION_TYPE_CONFIG] == Item::CREDITS_ONLY_CALCULATION_TYPE
          end
          qbo_ledger_line_item_details.select! { |lid| lid.accounting_class_qbo_id == accounting_class&.external_id } unless @report.accounting_class_check_disabled
          item_account_value_amount = qbo_ledger_line_item_details.sum(&:amount) || 0.00
        end
        item_value.item_account_values.new(chart_of_account_id: item_account.chart_of_account_id,
                                           accounting_class_id: item_account.accounting_class_id,
                                           name: item_account_value_name(business_chart_of_account: business_chart_of_account, accounting_class: accounting_class),
                                           value: item_account_value_amount.round(2))
        item_account_value_amount
      end

      def generate_item_account_value_with_bank_ledger(item_value:, item_account:, qbo_ledger:, common_ledger:, business_chart_of_account:, accounting_class:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/ParameterLists
        common_qbo_ledger_line_item_details = common_ledger.line_item_details.select do |lid|
          lid.chart_of_account_qbo_id == business_chart_of_account.qbo_id
        end
        common_qbo_ledger_line_item_details.select! do |lid|
          transaction_date = lid.transaction_date.to_date
          (transaction_date >= start_date_by_column) && (transaction_date <= @report_data.end_date)
        end
        common_qbo_ledger_line_item_details.select! { |lid| lid.accounting_class_qbo_id == accounting_class&.external_id } unless @report.accounting_class_check_disabled
        qbo_ledger_line_item_details = qbo_ledger.line_item_details.select do |lid|
          common_qbo_ledger_line_item_details.any? { |common_lid| common_lid.transaction_type == lid.transaction_type && common_lid.qbo_id == lid.qbo_id }
        end
        item_account_value_amount = qbo_ledger_line_item_details.sum(&:amount) || 0.00
        item_value.item_account_values.new(chart_of_account_id: item_account.chart_of_account_id,
                                           accounting_class_id: item_account.accounting_class_id,
                                           name: item_account_value_name(business_chart_of_account: business_chart_of_account, accounting_class: accounting_class),
                                           value: item_account_value_amount.round(2))
        item_account_value_amount
      end

      def generate_item_account_value_for_tax_ledger(item_value:, item_account:, bank_ledger:, ap_ledger:, common_ledger:, business_chart_of_account:, accounting_class:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/ParameterLists
        common_qbo_ledger_line_item_details = common_ledger.line_item_details.select do |lid|
          lid.chart_of_account_qbo_id == business_chart_of_account.qbo_id
        end
        common_qbo_ledger_line_item_details.select! do |lid|
          transaction_date = lid.transaction_date.to_date
          (transaction_date >= start_date_by_column) && (transaction_date <= @report_data.end_date)
        end
        common_qbo_ledger_line_item_details.select! { |lid| lid.accounting_class_qbo_id == accounting_class&.external_id } unless @report.accounting_class_check_disabled
        qbo_ledger_line_item_details = common_qbo_ledger_line_item_details.reject do |common_lid|
          bank_ledger.line_item_details.any? do |lid|
            (common_lid.transaction_type == lid.transaction_type) && (common_lid.qbo_id == lid.qbo_id)
          end
        end
        if @item.type_config[Item::EXCLUDE_LEDGERS_CONFIG] == Item::EXCLUDE_LEDGERS_BANK_AND_AP
          qbo_ledger_line_item_details = common_qbo_ledger_line_item_details.reject do |common_lid|
            ap_ledger.line_item_details.any? do |lid|
              (common_lid.transaction_type == lid.transaction_type) && (common_lid.qbo_id == lid.qbo_id)
            end
          end
        end
        item_account_value_amount = qbo_ledger_line_item_details.sum(&:amount) || 0.00
        item_value.item_account_values.new(chart_of_account_id: item_account.chart_of_account_id,
                                           accounting_class_id: item_account.accounting_class_id,
                                           name: item_account_value_name(business_chart_of_account: business_chart_of_account, accounting_class: accounting_class),
                                           value: item_account_value_amount.round(2))
        item_account_value_amount
      end

      def generate_net_change_item_account_value_with(item_value:, item_account:, qbo_ledgers:, business_chart_of_account:, accounting_class:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        previous_line_item_details = qbo_ledgers[:previous_period]&.line_item_details&.select { |lid| lid.chart_of_account_qbo_id == business_chart_of_account.qbo_id }
        previous_line_item_details&.select! { |lid| lid.accounting_class_qbo_id == accounting_class&.external_id }
        previous_value_amount = previous_line_item_details.sum(&:amount) || 0.00

        current_line_item_details = qbo_ledgers[:current_period]&.line_item_details&.select { |lid| lid.chart_of_account_qbo_id == business_chart_of_account.qbo_id }
        current_line_item_details&.select! { |lid| lid.accounting_class_qbo_id == accounting_class&.external_id }
        current_value_amount = current_line_item_details.sum(&:amount) || 0.00

        item_account_value_amount = current_value_amount - previous_value_amount

        item_value.item_account_values.new(chart_of_account_id: item_account.chart_of_account_id,
                                           accounting_class_id: item_account.accounting_class_id,
                                           name: item_account_value_name(business_chart_of_account: business_chart_of_account, accounting_class: accounting_class),
                                           value: item_account_value_amount.round(2))
        item_account_value_amount
      end
    end
  end
end
