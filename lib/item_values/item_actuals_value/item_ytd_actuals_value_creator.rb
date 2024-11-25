# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemYtdActualsValueCreator < BaseItemActualsValueCreator
      def call
        generate_for_ytd
      end

      private

      def generate_for_ytd
        if @item.type_config.present? && @item.type_config[Item::CALCULATION_TYPE_CONFIG] == Item::BS_PRIOR_DAY_CALCULATION_TYPE
          generate_for_ytd_with_january
        else
          generate_for_ytd_with_previous_month
        end
      end

      def generate_for_ytd_with_previous_month # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        current_actual_column = @report.detect_column(type: @column.type, range: Column::RANGE_CURRENT, year: @column.year)
        previous_month_ytd_item_value = nil
        if @report_data.start_date.month > 1 && @previous_month_report_data.present?
          previous_month_ytd_item_value = @previous_month_report_data.item_values.detect do |item_value|
            item_value.item_id == @item.id.to_s && item_value.column_id == @column.id.to_s
          end
        end
        current_actual_column_item_value = @report_data.item_values.detect do |item_value|
          item_value.item_id == @item.id.to_s && item_value.column_id == current_actual_column.id.to_s
        end

        ytd_item_values = [previous_month_ytd_item_value, current_actual_column_item_value].compact
        item_amount_value = if @item.type_config.present? && @item.type_config['name'] == Item::TYPE_METRIC && @report.enabled_blank_value_for_metric
                              if @report_data.start_date.month == 1
                                current_actual_column_item_value&.value
                              elsif (@previous_month_report_data.present? && previous_month_ytd_item_value&.value.nil?) || current_actual_column_item_value&.value.nil?
                                nil
                              else
                                ytd_item_values.map(&:value).compact.sum
                              end
                            else
                              ytd_item_values.map(&:value).compact.sum
                            end
        new_item_value = generate_item_value(item: @item, column: @column, item_amount: item_amount_value)
        copy_account_values(src_item_values: ytd_item_values, dst_item_value: new_item_value)
        new_item_value
      end

      def generate_for_ytd_with_january # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        current_actual_column = @report.detect_column(type: @column.type, range: Column::RANGE_CURRENT, year: @column.year)
        actual_column_item_value = if @report_data.start_date.month == 1
                                     @report_data.item_values.detect do |item_value|
                                       item_value.item_id == @item.id.to_s && item_value.column_id == current_actual_column.id.to_s
                                     end
                                   elsif @january_report_data_of_current_year.present?
                                     @january_report_data_of_current_year.item_values.detect do |item_value|
                                       item_value.item_id == @item.id.to_s && item_value.column_id == current_actual_column.id.to_s
                                     end
                                   end
        return if actual_column_item_value.nil?

        new_item_value = generate_item_value(item: @item, column: @column, item_amount: actual_column_item_value.value)
        copy_account_values(src_item_values: [actual_column_item_value], dst_item_value: new_item_value)
        new_item_value
      end
    end
  end
end
