# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemGeneralLedgerVendorActualsValueCreator < BaseItemActualsValueCreator
      def call
        generate_from_general_ledger
      end

      private

      def generate_from_general_ledger # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        item_value_amount = 0.00
        item_value = generate_item_value(item: @item, column: @column, item_amount: 0.0)

        qbo_ledger = @report_data.vendor_general_ledger
        business_vendor = @all_business_vendors.detect { |bv| bv.name == @item.identifier }
        if qbo_ledger.present?
          vendor_line_item_details = qbo_ledger.line_item_details.select do |lid|
            lid.vendor == business_vendor.qbo_name
          end
          all_category_qbo_ids = vendor_line_item_details.map(&:chart_of_account_qbo_id).uniq
          all_category_qbo_ids.each do |chart_of_account_qbo_id|
            business_chart_of_account = @all_business_chart_of_accounts.detect { |category| category.qbo_id == chart_of_account_qbo_id }
            next if business_chart_of_account.nil?

            category_line_item_details = vendor_line_item_details.select do |lid|
              lid.chart_of_account_qbo_id == chart_of_account_qbo_id
            end
            all_class_qbo_ids = vendor_line_item_details.map(&:accounting_class_qbo_id).uniq
            all_class_qbo_ids.each do |accounting_class_qbo_id|
              detailed_line_item_details = category_line_item_details.select do |lid|
                lid.accounting_class_qbo_id == accounting_class_qbo_id
              end
              accounting_class = @accounting_classes.detect { |business_accounting_class| business_accounting_class.external_id == accounting_class_qbo_id }
              item_account_value_amount = generate_item_account_value(item_value: item_value,
                                                                      line_item_details: detailed_line_item_details,
                                                                      business_chart_of_account: business_chart_of_account,
                                                                      accounting_class: accounting_class)
              item_value_amount += item_account_value_amount
            end
          end
        end
        value = item_value_amount.round(2)
        item_value.value = value
        item_value.accumulated_value = accumulated_value_from_previous_report_data(current_value: value)
        item_value.dependency_accumulated_value = calculate_dependency_accumulated_value
        item_value
      end

      def generate_item_account_value(item_value:, line_item_details:, business_chart_of_account:, accounting_class:) # rubocop:disable Metrics/MethodLength
        line_item_details.select! do |lid|
          transaction_date = lid.transaction_date.to_date
          (transaction_date >= start_date_by_column) && (transaction_date <= @report_data.end_date)
        end
        item_account_value_amount = line_item_details.sum(&:amount) || 0.00
        if item_account_value_amount.abs > 0.001
          item_value.item_account_values.new(chart_of_account_id: business_chart_of_account.chart_of_account_id,
                                             accounting_class_id: accounting_class&.id,
                                             name: item_account_value_name(business_chart_of_account: business_chart_of_account, accounting_class: accounting_class),
                                             value: item_account_value_amount.round(2))
        end
        item_account_value_amount
      end
    end
  end
end
