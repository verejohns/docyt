# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemActualsValueCreator < ItemValues::BaseItemValueCreator
      def call # rubocop:disable Metrics/MethodLength
        creator_instance = creator_class.new(
          report_data: @report_data, item: @item, column: @column,
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

      def creator_class # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        if @item.type_config.present? && @item.type_config['name'] == Item::TYPE_REFERENCE
          ItemReferenceActualsValueCreator
          # Below case is same with @item.type_config.present? && @item.type_config['name'] == Item::TYPE_STATS
          # But in Store Manager's Report(UPS report), type_config should be 'quickbooks_ledger', not 'stats'.
          # Because this report has several actual columns.
          # So values_config is used to check the column type for 'stats'.
        elsif @item.values_config.present? && @item.values_config[@column.type].present?
          ItemStatActualsValueCreator
        elsif @item.totals
          ItemTotalActualsValueCreator
        elsif @column.range == Column::RANGE_CURRENT || @column.range == Column::RANGE_MTD
          case @item.type_config['name']
          when Item::TYPE_METRIC
            ItemMetricActualsValueCreator
          when Item::TYPE_QUICKBOOKS_LEDGER
            general_ledger_actual_value_creator
          end
        else
          ItemYtdActualsValueCreator
        end
      end

      def general_ledger_actual_value_creator
        if @report.vendor_report?
          ItemGeneralLedgerVendorActualsValueCreator
        else
          ItemGeneralLedgerActualsValueCreator
        end
      end
    end
  end
end
