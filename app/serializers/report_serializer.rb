# frozen_string_literal: true

# == Mongoid Information
#
# Document name: reports
#
#  id                   :string
#  report_service_id    :integer
#  template_id          :string
#  name                 :string
#

class ReportSerializer < ActiveModel::MongoidSerializer
  include ActionView::Helpers::DateHelper
  attributes :id, :report_service_id, :template_id, :name, :update_state
  attributes :item_accounts_count, :updated_time_string
  attributes :accessible_user_ids, :error_msg, :view_by_options, :period_type
  attributes :enabled_budget_compare, :total_column_visible, :enabled_default_mapping, :edit_mapping_disabled
  attributes :accepted_accounting_class_ids, :accepted_account_types

  has_many :ptd_columns, each_serializer: ColumnSerializer
  has_many :mtd_columns, each_serializer: ColumnSerializer
  has_many :ytd_columns, each_serializer: ColumnSerializer

  delegate :enabled_default_mapping, to: :object

  def item_accounts_count
    object.all_item_accounts.count
  end

  def updated_time_string
    if object.updated_at.blank?
      nil
    elsif object.updated_at > 7.days.ago.to_date
      "#{time_ago_in_words(object.updated_at).sub('about ', '')} ago"
    else
      object.updated_at.strftime('%m/%d/%Y')
    end
  end

  def ptd_columns
    object.columns.where(range: Column::RANGE_CURRENT).order_by(order: :asc)
  end

  def mtd_columns
    object.columns.where(range: Column::RANGE_MTD).order_by(order: :asc)
  end

  def ytd_columns
    object.columns.where(range: Column::RANGE_YTD).order_by(order: :asc)
  end

  def accessible_user_ids
    object.report_users.pluck(:user_id)
  end

  # For frontend backward compatibility
  def report_service_id
    object.report_service.service_id
  end

  def period_type
    object.report_template&.period_type || Report::PERIOD_MONTHLY
  end
end
