# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemReferenceActualsValueCreator < BaseItemActualsValueCreator
      def call
        generate_from_reference
      end

      private

      def generate_from_reference # rubocop:disable Metrics/MethodLength
        column_range = @item.type_config['src_column_range'].presence || @column.range
        reference_item_value = actual_item_value_by_identifier_with_dependency(
          identifier: @item.type_config['reference'],
          column_type: @column.type, column_range: column_range, column_year: @column.year
        )
        item_amount = reference_item_value&.value || 0.0
        accumulated_value_amount = reference_item_value&.accumulated_value || 0.0
        dependency_accumulated_value_amount = reference_item_value&.dependency_accumulated_value || 0.0
        item_value = generate_item_value(
          item: @item, column: @column, item_amount: item_amount, accumulated_value_amount: accumulated_value_amount,
          dependency_accumulated_value_amount: dependency_accumulated_value_amount
        )
        item_value.column_type = reference_item_value&.column_type
        item_value
      end
    end
  end
end
