# frozen_string_literal: true

module Api
  module V1
    class ReportsController < ApplicationController
      def show
        report = Report.find(params[:id])
        ensure_report_access(report: report, operation: :read)
        render status: :ok, json: report, serializer: ::ReportSerializer
      end

      def update
        report = Report.find(params[:id])
        ensure_report_service_access(report_service: report.report_service, operation: :write)
        report_result = ReportFactory.update(report: report, report_params: report_params)
        if report_result.success?
          render status: :ok, json: report.reload, serializer: ::ReportSerializer
        else
          render status: 422, json: { errors: report_result.errors }
        end
      end

      def destroy
        report = Report.find(params[:id])
        ensure_report_access(report: report, operation: :write)
        report.destroy!
        render status: :ok, json: { success: true }
      end

      def update_report
        report = Report.find(params[:id])
        ensure_report_access(report: report, operation: :write)
        ReportFactory.enqueue_report_update(report)
        render status: :ok, json: report.reload, serializer: ::ReportSerializer
      end

      def available_businesses
        render status: :ok, json: BusinessesQuery.new.available_businesses(user: secure_user, template_id: params[:template_id]), root: 'available_businesses'
      end

      private

      def report_params
        params.require(:report).permit(:template_id, :name, user_ids: [], accepted_accounting_class_ids: [], accepted_account_types: %i[account_type account_detail_type])
      end
    end
  end
end
