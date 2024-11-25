# frozen_string_literal: true

class ReportDataSerializer < ActiveModel::MongoidSerializer
  attributes :id, :period_type, :start_date, :end_date, :update_state, :error_msg
  attributes :budget_ids
  attributes :unincluded_transactions_count
  has_many :item_values, each_serializer: ItemValueSerializer

  def start_date
    object.start_date.to_s
  end

  def end_date
    object.end_date.to_s
  end

  delegate :unincluded_transactions_count, to: :object
end
