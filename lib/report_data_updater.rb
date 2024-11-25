# frozen_string_literal: true

class ReportDataUpdater < BaseReportDataUpdater
  def update_report_data(report_data:)
    start_report_data_update(report_data) do |_qbo_authorization|
      ReportFactory.refill_daily_report_data(report_data: report_data)
    end
  end
  apm_method :update_report_data
end
