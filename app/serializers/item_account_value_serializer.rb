# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: item_values
#
#  id                   :string
#  chart_of_account_id  :Integer
#  accounting_class_id  :Integer
#  name                 :string
#  value                :float
#

class ItemAccountValueSerializer < ActiveModel::MongoidSerializer
  attributes :id, :chart_of_account_id, :accounting_class_id, :name, :value
end
