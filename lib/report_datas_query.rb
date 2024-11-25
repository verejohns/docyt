# frozen_string_literal: true

class ReportDatasQuery < ReportDatasBaseQuery
  def initialize(report:, report_datas_params:, include_total:)
    super()
    @report = report
    @start_date = report_datas_params[:from]&.to_date
    @end_date = report_datas_params[:to]&.to_date
    @current_date = report_datas_params[:current]&.to_date
    @include_total = include_total
    @is_daily = report_datas_params[:is_daily]
  end

  def report_datas
    if @is_daily
      daily_report_datas
    else
      monthly_report_datas
    end
  end

  def daily_report_datas
    report_data = @report.report_datas.find_by(start_date: @current_date, end_date: @current_date, period_type: ReportData::PERIOD_DAILY)
    if report_data.nil?
      report_data = ReportData.new(
        report: @report,
        period_type: ReportData::PERIOD_DAILY,
        start_date: @current_date, end_date: @current_date
      )
      report_data.save!
    end
    [report_data]
  end

  def monthly_report_datas
    @report_datas = generate_monthly_report_datas(start_date: @start_date, end_date: @end_date)
    return @report_datas unless @include_total && @report_datas.length > 1

    @report_datas.unshift(generate_total_report_data)
    @report_datas
  end

  def generate_total_report_data # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    origin_report_datas = @report.report_datas.where(start_date: { '$gt' => (@start_date - 1.day) },
                                                     end_date: { '$lt' => (@end_date + 1.day) },
                                                     period_type: ReportData::PERIOD_MONTHLY)
    total_report_data = ReportData.new(report: @report, period_type: ReportData::PERIOD_MONTHLY, start_date: @start_date, end_date: @end_date)
    return total_report_data if @start_date + 1.month > @end_date || origin_report_datas.empty?

    return origin_report_datas.first if origin_report_datas.length == 1

    items = total_report_data.report.report_items
    start_report_data = generate_report_data(start_date: @start_date - 1.month, end_date: @start_date - 1.day)

    if @report.template_id == Report::STORE_MANAGERS_REPORT
      @data_column = @report.columns.find_by(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      @percentage_column = @report.columns.find_by(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      update_total_report_data(start_report_data: start_report_data, end_report_data: origin_report_datas.last, total_report_data: total_report_data, items: items)
    end
    @data_column = @report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
    @percentage_column = @report.columns.find_by(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
    update_total_report_data(start_report_data: start_report_data, end_report_data: origin_report_datas.last, total_report_data: total_report_data, items: items)
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

  def generate_report_data(start_date:, end_date:)
    report_data = @report.report_datas.find_by(start_date: { '$gt' => start_date - 1.day }, end_date: { '$lt' => end_date + 1.day })
    if report_data.nil?
      report_data = ReportData.new(
        report: @report,
        period_type: ReportData::PERIOD_MONTHLY,
        start_date: start_date,
        end_date: end_date
      )
    end
    report_data
  end

  def update_total_report_data(start_report_data:, end_report_data:, total_report_data:, items:)
    return total_report_data if @data_column.nil?

    generate_total_item_values(start_report_data: start_report_data, end_report_data: end_report_data,
                               total_report_data: total_report_data, column: @data_column, report_items: items)
    # We have to recalculate '%', '/' items for total report data
    recalculate_for_total_report_data(report_data: total_report_data, column: @data_column, report_items: items)

    return total_report_data if @percentage_column.nil?

    recalculate_for_total_report_data(report_data: total_report_data, column: @percentage_column, report_items: items)
    total_report_data
  end

  def generate_total_item_values(start_report_data:, end_report_data:, total_report_data:, column:, report_items:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    report_items.each do |item|
      next if item.type_config.blank? && !item.totals

      start_item_value = item_value_from_report_data(report_data: start_report_data, item: item, column: column)
      end_item_value = item_value_from_report_data(report_data: end_report_data, item: item, column: column)

      total_item_value_amount = (end_item_value&.accumulated_value || 0.0) - (start_item_value&.accumulated_value || 0.0)
      total_dependency_item_value_amount = (end_item_value&.dependency_accumulated_value || 0.0) - (start_item_value&.dependency_accumulated_value || 0.0)
      total_item_value = total_report_data.item_values.new(item_id: item._id.to_s, column_id: column.id.to_s, value: total_item_value_amount, item_identifier: item.identifier,
                                                           dependency_accumulated_value: total_dependency_item_value_amount)
      total_item_value.column_type = end_item_value&.column_type
    end
  end
end
