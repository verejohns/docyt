# frozen_string_literal: true

module Api
  module V1
    class ReportDatasController < ApplicationController
      def by_range
        ensure_report_access(report: report, operation: :read)
        report_data_query = ReportDatasQuery.new(report: report, report_datas_params: report_datas_params, include_total: report.total_column_visible)
        report_datas = report_data_query.report_datas
        if report_datas.blank?
          render status: :ok, json: []
        else
          render status: :ok, json: report_datas, each_serializer: ::ReportDataSerializer
        end
      end

      def update_data
        ensure_report_access(report: report, operation: :write)
        report_data = report.report_datas.find_by(start_date: params[:current_date].to_date, end_date: params[:current_date].to_date)
        ReportFactory.enqueue_report_data_update(report_data)
        render status: :ok, json: report_data.reload, serializer: ::ReportDataSerializer
      end

      def report_datas_params
        params.permit(:from, :to, :current, :is_daily)
      end
    end
  end
end
