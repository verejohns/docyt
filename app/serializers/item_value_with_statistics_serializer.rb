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
#

class ItemValueWithStatisticsSerializer < ItemValueSerializer
  attributes :report_year, :report_month, :item_name, :value_type
  has_many :item_account_values, serializer: ItemAccountValueSerializer

  def report_year
    current_year = object.report_data.end_date.year
    if column.year == Column::YEAR_CURRENT
      current_year
    else
      current_year - 1
    end
  end

  def report_month
    object.report_data.end_date.month
  end

  delegate :name, to: :item, prefix: true

  def value_type
    if column.range == Column::RANGE_CURRENT
      'Current'
    else
      'YTD'
    end
  end

  private

  def item
    @item ||= object.report_data.report.find_item_by_id(id: object.item_id)
  end

  def column
    @column ||= object.report_data.report.columns.find(object.column_id)
  end
end
