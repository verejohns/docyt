# frozen_string_literal: true

module Api
  module V1
    class AdvancedReportsController < ApplicationController
      def index
        if user_access_manager.can_access_to_report_service(report_service: report_service, operation: :write)
          reports = AdvancedReport.where(report_service: report_service).all
        elsif user_access_manager.can_access_to_report_service(report_service: report_service, operation: :read)
          reports = AdvancedReport.where(report_service: report_service, report_users: { '$elemMatch' => { user_id: secure_user.id } }).all
        else
          raise NoPermissionException
        end
        render status: :ok, json: reports, each_serializer: ::ReportSerializer
      end

      def create
        @report_service = ReportService.find_by(service_id: params[:advanced_report][:report_service_id]) # For backward compatibility
        ensure_report_service_access(report_service: report_service, operation: :write)
        result = AdvancedReportFactory.create(report_service: report_service, report_params: report_params.to_h, current_user: secure_user)
        if result.success?
          render status: :created, json: result.report, serializer: ::ReportSerializer, root: 'report'
        else
          render status: :unprocessable_entity, json: { errors: result.errors }
        end
      end

      private

      def report_params
        params.require(:advanced_report).permit(:template_id, :name, user_ids: [])
      end
    end
  end
end
