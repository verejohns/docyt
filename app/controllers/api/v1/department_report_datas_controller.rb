# frozen_string_literal: true

module Api
  module V1
    class DepartmentReportDatasController < ApplicationController
      def by_range
        ensure_report_access(report: report, operation: :read)
        report_data_query = DepartmentReportDatasQuery.new(report: report, report_datas_params: report_datas_params, include_total: true)
        report_datas = report_data_query.department_report_datas
        if report_datas.blank?
          render status: :ok, json: []
        else
          render status: :ok, json: report_datas, each_serializer: ::ReportDataSerializer, root: 'report_datas'
        end
      end

      def report_datas_params
        params.permit(:from, :to, filter: {})
      end
    end
  end
end
