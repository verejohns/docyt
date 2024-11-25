# frozen_string_literal: true

class ItemValuesQuery
  def initialize(report:, item_values_params:)
    super()
    @report = report
    @item_values_params = item_values_params
    @start_date = item_values_params[:from]&.to_date
    @end_date = item_values_params[:to]&.to_date
    @item_id = item_values_params[:item_id]
  end

  def item_values # rubocop:disable Metrics/MethodLength
    report_datas = generate_monthly_report_datas(start_date: @start_date, end_date: @end_date)
    if report_datas.length == 1
      column_ids = @report.columns.select { |column| [Column::TYPE_ACTUAL, Column::TYPE_GROSS_ACTUAL, Column::TYPE_VARIANCE].include?(column.type) }.map do |column|
        column.id.to_s
      end
      report_datas.first.item_values.select { |iv| iv.item_id == @item_id && column_ids.include?(iv.column_id) }
    else
      item = @report.find_item_by_id(id: @item_id)
      column = @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      report_datas.map do |report_data|
        generate_item_value(report_data: report_data, item: item, column: column)
      end
    end
  end

  private

  def generate_monthly_report_datas(start_date:, end_date:) # rubocop:disable Metrics/MethodLength
    monthly_report_datas = []
    date = start_date
    while date < end_date
      report_data = @report.report_datas.where(start_date: { '$gt' => (date - 1.day) }, end_date: { '$lt' => (date + 1.month) }, period_type: ReportData::PERIOD_MONTHLY).first
      if report_data.nil?
        report_data = ReportData.new(
          report: @report,
          period_type: ReportData::PERIOD_MONTHLY,
          start_date: date,
          end_date: date + 1.month - 1.day
        )
      end
      monthly_report_datas << report_data
      date += 1.month
    end
    monthly_report_datas
  end

  def generate_item_value(report_data:, item:, column:)
    item_value = report_data.item_values.detect { |iv| iv.item_id == item.id.to_s && iv.column_id == column.id.to_s }
    return item_value if item_value.present?

    report_data.item_values.new(item_id: item.id.to_s, item_identifier: item.identifier, column_id: column.id.to_s)
  end
end
