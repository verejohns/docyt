# frozen_string_literal: true

class ReportsInReportServiceUpdater < BaseReportDataUpdater
  def update_all_reports(report_service) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    qbo_authorization = Quickbooks::GeneralLedgerImporter.fetch_qbo_token(report_service)
    if qbo_authorization.nil?
      report_service.reports.each do |report|
        report.update!(update_state: Report::UPDATE_STATE_FAILED, error_msg: Report::ERROR_MSG_QBO_NOT_CONNECTED)
      end
      return
    end

    report_service.reports.each do |report|
      report.update!(update_state: Report::UPDATE_STATE_QUEUED)
    end

    fetch_bookkeeping_start_date(report_service)
    fetch_general_ledgers(report_service: report_service, qbo_authorization: qbo_authorization)
    Report.where(report_service: report_service).each do |report|
      next if report.dependent_template_ids.present?

      report.refresh_all_report_datas
    end
    report_service.update!(updated_at: Time.zone.now)
  rescue OAuth2::Error => e
    err_msg = Quickbooks::Error.error_message(error: e)
    report_service.reports.map { |report| report.update!(update_state: Report::UPDATE_STATE_FAILED, error_msg: err_msg) }
    DocytLib.logger.debug(err_msg)
    Rollbar.error(e) if err_msg == Quickbooks::Error::UNKNOWN_ERROR
  end
  apm_method :update_all_reports

  def update_report(report)
    start_report_update(report) do |qbo_authorization|
      fetch_bookkeeping_start_date(report.report_service)
      fetch_general_ledgers(report_service: report.report_service, qbo_authorization: qbo_authorization)
      report.refresh_all_report_datas(ReportFactory::MANUAL_UPDATE_PRIORITY)
    end
  end
  apm_method :update_report
end
