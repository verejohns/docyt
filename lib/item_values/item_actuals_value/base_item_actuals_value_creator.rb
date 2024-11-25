# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class BaseItemActualsValueCreator < ItemValues::BaseItemValueCreator
      private

      # This method calculates the dependency accumulated value for percentage calculation
      def calculate_dependency_accumulated_value
        expression = item_expression(item: @item, target_column_type: Column::TYPE_PERCENTAGE)
        return 0.0 if expression.nil? || expression['arg1'].nil?

        if expression['arg1']['item_id'].include?('/')
          dependency_accumulated_value_by_identifier(identifier: expression['arg1']['item_id'])
        elsif expression['arg2']['item_id'].include?('/')
          dependency_accumulated_value_by_identifier(identifier: expression['arg2']['item_id'])
        else
          0.0
        end
      end

      def dependency_accumulated_value_by_identifier(identifier:)
        identifier_values = identifier.split('/')
        return 0.0 unless identifier_values.length == 2 && @dependent_report_datas.include?(identifier_values[0])

        dependent_report_data = @dependent_report_datas[identifier_values[0]]
        target_column = dependent_report_data.report.columns.find_by(type: @column.type, range: @column.range, year: @column.year)
        dependent_item_value = dependent_report_data.item_values.detect do |item_value|
          item_value.item_identifier == identifier_values[1] && item_value.column_id == target_column.id.to_s
        end
        dependent_item_value&.accumulated_value || 0.0
      end

      def item_account_value_name(business_chart_of_account:, accounting_class:)
        if accounting_class.present?
          "#{accounting_class.name} ▸ #{business_chart_of_account.display_name}"
        else
          business_chart_of_account.display_name
        end
      end
    end
  end
end
