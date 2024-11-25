# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemTotalActualsValueCreator < BaseItemActualsValueCreator
      def call
        generate_total_value
      end

      private

      def generate_total_value # rubocop:disable Metrics/MethodLength
        child_items = @item.parent_item.child_items.reject { |child_item| child_item.id == @item.id }
        child_item_values = child_items.map do |child_item|
          child_total_item = if child_item.child_items.present?
                               child_item.total_item
                             else
                               child_item
                             end
          item_value = actual_value_by_identifier(identifier: child_total_item.identifier, column: @column)
          value = item_value&.value || 0.0
          child_total_item.negative_for_total ? -value : value
        end

        item_amount = child_item_values.sum + parent_item_value
        generate_item_value(item: @item, column: @column, item_amount: item_amount,
                            accumulated_value_amount: accumulated_value_from_previous_report_data(current_value: item_amount),
                            dependency_accumulated_value_amount: calculate_dependency_accumulated_value)
      end

      def parent_item_value
        parent_item = @item.parent_item
        return 0.0 if parent_item.type_config.blank?

        parent_item_value = actual_value_by_identifier(identifier: parent_item.identifier, column: @column)
        parent_value = parent_item_value&.value || 0.0
        parent_item.negative ? -parent_value : parent_value
      end
    end
  end
end
