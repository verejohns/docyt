# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: columns
#
#  id                   :string
#  type                 :string
#  period               :string
#

class ColumnSerializer < ActiveModel::MongoidSerializer
  attributes :id, :type, :range, :year, :name
end
