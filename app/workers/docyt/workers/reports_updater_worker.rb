# frozen_string_literal: true

module Docyt
  module Workers
    class ReportsUpdaterWorker
      include DocytLib::Async::Worker
      subscribe :refresh_report_request
      prefetch 1

      def perform(event)
        report = Report.find(event[:report_id])
        DocytLib.logger.info("Worker for ReportData started, Report ID: #{report.id}")
        update_report(report: report)
        Quickbooks::UnincludedLineItemDetailsFactory.create_for_report(report: report) unless report.missing_transactions_calculation_disabled
        update_depends_on_report(current_report: report)
        DocytLib.logger.info('Worker successfully performed running.')
      end

      private

      def update_report(report:)
        report.refill_report
      end

      def update_depends_on_report(current_report:)
        reports = Report.where(report_service_id: current_report.report_service_id)
        reports.each do |report|
          next unless report.dependent_template_ids.present? && report.dependent_template_ids.include?(current_report.template_id)

          report.refresh_all_report_datas
        end
      end
    end
  end
end
