# frozen_string_literal: true

module Docyt
  module Workers
    class ReportDataUpdaterWorker
      include DocytLib::Async::Worker
      subscribe :refresh_report_data
      prefetch 1

      def perform(event)
        report_data = ReportData.find(event[:report_data_id])
        DocytLib.logger.info("Worker for ReportData started, Report Data ID: #{event[:report_data_id]}")
        ReportDataUpdater.update_report_data(report_data: report_data)
        DocytLib.logger.info('Worker successfully performed running.')
      end
    end
  end
end
