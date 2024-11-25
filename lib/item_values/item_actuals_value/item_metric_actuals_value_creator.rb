# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemMetricActualsValueCreator < ItemValues::BaseItemValueCreator
      def call
        generate_from_metric
      end

      private

      def generate_from_metric
        metrics_service_value_api_instance = MetricsServiceClient::ValueApi.new
        metric_code = @item.type_config['metric']['code']
        response = metrics_service_value_api_instance.get_metric_value(@report.report_service.business_id, metric_code, start_date_by_column, @report_data.end_date)
        item_amount = @report.enabled_blank_value_for_metric ? response.value : response.value.to_f
        generate_item_value(
          item: @item, column: @column, item_amount: item_amount,
          accumulated_value_amount: accumulated_value_from_previous_report_data(current_value: item_amount.to_f)
        )
      end
    end
  end
end
