# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: item_values
#
#  id                   :string
#  value                :string
#  item_id              :ObjectId
#  column_id            :ObjectId
#  value                :Float
#  item_identifier      :string
#

class ItemValueSerializer < ActiveModel::MongoidSerializer
  attributes :id, :item_id, :column_id, :value, :item_identifier, :column_type, :budget_values

  def item_id
    object.item_id.to_s
  end

  def column_id
    object.column_id.to_s
  end
end
