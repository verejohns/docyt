# frozen_string_literal: true

module AccountValue
  class ItemAccountValuesQuery
    def initialize(report:, item_account_values_params:)
      @report = report
      @start_date = item_account_values_params[:from].to_date
      @end_date = item_account_values_params[:to].to_date
      @item_identifier = item_account_values_params[:item_identifier]
      @item = report.find_item_by_identifier(identifier: @item_identifier)
    end

    def item_account_values # rubocop:disable Metrics/MethodLength
      return [] if @item.nil?

      item_values = []
      # Now first and second drill down are implemented for only MONTHLY PERIOD
      report_datas = @report.report_datas.where(start_date: { '$gt' => (@start_date - 1.day) }, end_date: { '$lt' => @end_date + 1.day },
                                                period_type: ReportData::PERIOD_MONTHLY)
      report_datas.each do |report_data|
        item_values += report_data.item_values.where(item_id: @item.id, column_id: current_actual_column.id)
      end
      if @report.vendor_report?
        item_values.map(&:item_account_values).flatten
      else
        generate_total_item_account_values(item_values: item_values)
      end
    end

    private

    def current_actual_column
      @current_actual_column ||= @report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
    end

    def generate_total_item_account_values(item_values:) # rubocop:disable Metrics/MethodLength
      return [] if item_values.blank?

      total_item_account_values = []
      @item.mapped_item_accounts.each do |item_account, index|
        item_account_values = item_values.map do |item_value|
          item_value.item_account_values.find_by(chart_of_account_id: item_account.chart_of_account_id,
                                                 accounting_class_id: item_account.accounting_class_id)
        end
        item_account_values = item_account_values.compact
        total_value = item_account_values.map(&:value).sum || 0.0
        total_item_account_values << Struct.new(:id, :chart_of_account_id, :accounting_class_id, :value, :name).new(
          index, item_account.chart_of_account_id, item_account.accounting_class_id, total_value, item_account_values.first&.name
        )
      end
      total_item_account_values
    end
  end
end
