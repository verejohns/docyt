# frozen_string_literal: true

class ItemFactory
  include DocytLib::Utils::DocytInteractor
  attr_accessor :item

  def create(parent_item:, name:)
    order = if parent_item.child_items.present?
              parent_item.child_items.max(:order) + 1
            else
              1
            end
    @item = parent_item.child_items.find_or_create_by!(name: name, order: order, identifier: name)
  end
end
