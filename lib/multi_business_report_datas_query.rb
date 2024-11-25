# frozen_string_literal: true

class MultiBusinessReportDatasQuery < ReportDatasBaseQuery # rubocop:disable Metrics/ClassLength
  def initialize(multi_business_report:, report_datas_params:)
    super()
    @multi_business_report = multi_business_report
    @start_date = report_datas_params[:from]&.to_date
    @end_date = report_datas_params[:to]&.to_date
    @current_date = report_datas_params[:current]&.to_date
    @is_daily = report_datas_params[:is_daily]
  end

  def report_datas
    if @is_daily
      @period_type = ReportData::PERIOD_DAILY
      daily_report_datas
    else
      @period_type = ReportData::PERIOD_MONTHLY
      monthly_report_datas
    end
  end

  private

  def daily_report_datas
    @report_datas = generate_business_daily_report_datas(current_date: @current_date)
    return @report_datas unless @report_datas.length.positive?

    aggregated_report_data = generate_aggregated_report_data(multi_business_report_datas: @report_datas, start_date: @current_date, end_date: @current_date)
    @report_datas.unshift(aggregated_report_data)
    @report_datas
  end

  def generate_business_daily_report_datas(current_date:)
    multi_business_report_datas = []
    @multi_business_report.reports.each do |report|
      report_datas_params = { current: current_date, is_daily: true }
      query = ReportDatasQuery.new(report: report, report_datas_params: report_datas_params, include_total: true)
      multi_business_report_datas << query.report_datas.first
    end
    multi_business_report_datas
  end

  def monthly_report_datas
    @report_datas = generate_business_monthly_report_datas(start_date: @start_date, end_date: @end_date)
    return @report_datas unless @report_datas.length.positive?

    aggregated_report_data = generate_aggregated_report_data(multi_business_report_datas: @report_datas, start_date: @start_date, end_date: @end_date)
    @report_datas.unshift(aggregated_report_data)
    @report_datas
  end

  def generate_business_monthly_report_datas(start_date:, end_date:)
    multi_business_report_datas = []
    @multi_business_report.reports.each do |report|
      report_datas_params = { from: start_date, to: end_date }
      query = ReportDatasQuery.new(report: report, report_datas_params: report_datas_params, include_total: true)
      multi_business_report_datas << query.report_datas.first
    end
    multi_business_report_datas
  end

  def generate_aggregated_report_data(multi_business_report_datas:, start_date:, end_date:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    aggregated_report_data = ReportData.new(
      report: multi_business_report_datas[0].report,
      period_type: @period_type,
      start_date: start_date,
      end_date: end_date
    )

    get_config_info(report_datas: multi_business_report_datas, aggregated_report_data: aggregated_report_data)
    @aggregated_actual_column = aggregated_report_data.report.columns.detect do |column|
      column.type == Column::TYPE_ACTUAL && column.range == Column::RANGE_CURRENT && column.year == Column::YEAR_CURRENT
    end
    return aggregated_report_data if @aggregated_actual_column.nil?

    items = @multi_business_report.all_report_items
    generate_aggregated_item_values(report_data: aggregated_report_data, multi_business_report_datas: multi_business_report_datas,
                                    aggregated_column: @aggregated_actual_column, items: items)
    # We have to recalculate '%', '/' items for total report data
    recalculate_for_total_report_data(report_data: aggregated_report_data, column: @aggregated_actual_column, report_items: items)
    @aggregated_percentage_column = aggregated_report_data.report.columns.detect do |column|
      column.type == Column::TYPE_PERCENTAGE && column.range == Column::RANGE_CURRENT && column.year == Column::YEAR_CURRENT
    end
    return aggregated_report_data if @aggregated_percentage_column.nil?

    recalculate_for_total_report_data(report_data: aggregated_report_data, column: @aggregated_percentage_column, report_items: items)
    return aggregated_report_data unless @multi_business_report.gross_value?

    @gross_aggregated_actual_column = aggregated_report_data.report.columns.detect do |column|
      column.type == Column::TYPE_GROSS_ACTUAL && column.range == Column::RANGE_CURRENT && column.year == Column::YEAR_CURRENT
    end
    return aggregated_report_data if @gross_aggregated_actual_column.nil?

    generate_aggregated_item_values(report_data: aggregated_report_data, multi_business_report_datas: multi_business_report_datas,
                                    aggregated_column: @gross_aggregated_actual_column, items: items)
    # We have to recalculate '%', '/' items for total report data
    recalculate_for_total_report_data(report_data: aggregated_report_data, column: @gross_aggregated_actual_column, report_items: items)
    @aggregated_percentage_column = aggregated_report_data.report.columns.detect do |column|
      column.type == Column::TYPE_GROSS_PERCENTAGE && column.range == Column::RANGE_CURRENT && column.year == Column::YEAR_CURRENT
    end
    return aggregated_report_data if @aggregated_percentage_column.nil?

    recalculate_for_total_report_data(report_data: aggregated_report_data, column: @aggregated_percentage_column, report_items: items)
    aggregated_report_data
  end

  def get_config_info(report_datas:, aggregated_report_data:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    @data_column = aggregated_report_data.report.columns.detect do |column|
      column.type == Column::TYPE_ACTUAL && column.range == Column::RANGE_CURRENT && column.year == Column::YEAR_CURRENT
    end
    @percentage_column = aggregated_report_data.report.columns.detect do |column|
      column.type == Column::TYPE_PERCENTAGE && column.range == Column::RANGE_CURRENT && column.year == Column::YEAR_CURRENT
    end
    @gross_data_column = aggregated_report_data.report.columns.detect do |column|
      column.type == Column::TYPE_GROSS_ACTUAL && column.range == Column::RANGE_CURRENT && column.year == Column::YEAR_CURRENT
    end
    @gross_percentage_column = aggregated_report_data.report.columns.detect do |column|
      column.type == Column::TYPE_GROSS_PERCENTAGE && column.range == Column::RANGE_CURRENT && column.year == Column::YEAR_CURRENT
    end
    @actual_columns = all_columns(report_datas: report_datas, column_type: Column::TYPE_ACTUAL)
    @gross_actual_columns = all_columns(report_datas: report_datas, column_type: Column::TYPE_GROSS_ACTUAL)
    @items = aggregated_report_data.report.report_items
  end

  def get_actual_column(report_data_id:)
    @actual_columns[report_data_id]
  end

  def get_gross_actual_column(report_data_id:)
    @gross_actual_columns[report_data_id]
  end

  def all_columns(report_datas:, column_type:)
    columns = {}
    report_datas.each do |report_data|
      column = report_data.report.columns.detect do |cl|
        cl.type == column_type && cl.range == Column::RANGE_CURRENT && cl.year == Column::YEAR_CURRENT
      end
      next if column.nil?

      columns[report_data.id.to_s] = column
    end
    columns
  end

  def generate_aggregated_item_values(report_data:, multi_business_report_datas:, aggregated_column:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    items.each do |item|
      aggregated_item_amount = 0.0
      dependency_accumulated_amount = 0.0
      multi_business_report_datas.each do |multi_business_report_data|
        column = if aggregated_column.type == Column::TYPE_GROSS_ACTUAL
                   get_gross_actual_column(report_data_id: multi_business_report_data.id.to_s)
                 else
                   get_actual_column(report_data_id: multi_business_report_data.id.to_s)
                 end
        item_value = multi_business_report_data.item_values.detect { |iv| iv.item_identifier == item.identifier && iv.column_id == column.id.to_s }
        aggregated_item_amount += item_value&.value || 0.0
        dependency_accumulated_amount += item_value&.dependency_accumulated_value || 0.0
      end
      aggregated_item_value = report_data.item_values.new(item_id: item.id.to_s, column_id: aggregated_column.id.to_s,
                                                          value: aggregated_item_amount.round(2), item_identifier: item.identifier,
                                                          dependency_accumulated_value: dependency_accumulated_amount)
      aggregated_item_value.generate_column_type_with_infos(item: item, column: aggregated_column)
    end
  end
end
