# frozen_string_literal: true

module Docyt
  module Workers
    class ReportServiceUpdaterWorker
      include DocytLib::Async::Worker
      subscribe :refresh_reports
      # This is a slow worker therefore we need to avoid prefetching too many messages to make sure that priorities are working correctly
      prefetch 1

      def perform(event)
        if event[:report_id].blank?
          report_service = ReportService.find(event[:report_service_id])
          DocytLib.logger.info("Worker for ReportData started, Report Service ID: #{event[:report_service_id]}")
          ReportsInReportServiceUpdater.update_all_reports(report_service)
        else
          report = Report.find(event[:report_id])
          DocytLib.logger.info("Worker for ReportData started, Report ID: #{event[:report_id]}")
          ReportsInReportServiceUpdater.update_report(report)
        end
        DocytLib.logger.info('Worker successfully performed running.')
      end
    end
  end
end
