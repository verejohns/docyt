# frozen_string_literal: true

class BaseReportDataUpdater < BaseService
  class QuickbooksIsNotConnectedError < StandardError; end

  include DocytLib::Helpers::PerformanceHelpers
  include DocytLib::Async::Publisher

  private

  def start_report_update(report)
    report_service = report.report_service
    begin
      qbo_authorization = Quickbooks::GeneralLedgerImporter.fetch_qbo_token(report_service)
      raise QuickbooksIsNotConnectedError unless qbo_authorization

      yield(qbo_authorization)
      report.update!(updated_at: Time.zone.now, update_state: Report::UPDATE_STATE_FINISHED, error_msg: nil)
    rescue StandardError => e
      handle_error(report, e)
    end
  end

  def start_report_data_update(report_data) # rubocop:disable Metrics/MethodLength
    report = report_data.report
    report_service = report.report_service

    begin
      qbo_authorization = Quickbooks::GeneralLedgerImporter.fetch_qbo_token(report_service)
      raise QuickbooksIsNotConnectedError unless qbo_authorization

      yield(qbo_authorization)
      report_data.update!(updated_at: Time.zone.now, update_state: Report::UPDATE_STATE_FINISHED, error_msg: nil)
    rescue StandardError => e
      handle_error(report_data, e)
    ensure
      publish(events.report_data_generated(report_data_id: report_data.id.to_s))
    end
  end

  def handle_error(obj, error)
    err_msg = case error
              when QuickbooksIsNotConnectedError
                Report::ERROR_MSG_QBO_NOT_CONNECTED
              when OAuth2::Error
                Quickbooks::Error.error_message(error: error)
              else
                'Unexpected error'
              end

    obj.update!(update_state: Report::UPDATE_STATE_FAILED, error_msg: err_msg)
    Rollbar.error(error)
  end

  def fetch_general_ledgers(report_service:, qbo_authorization:)
    current_date = Date.new(@bookkeeping_start_date.year, 1, 1)
    fetch_balance_sheet(report_service: report_service, date: current_date - 1.month, qbo_authorization: qbo_authorization)
    while current_date <= Time.zone.today
      start_date = Date.new(current_date.year, current_date.month, 1)
      end_date = Date.new(current_date.year, current_date.month, -1)
      current_date += 1.month
      fetch_general_ledger(report_service: report_service, start_date: start_date, end_date: end_date, qbo_authorization: qbo_authorization)
    end
    report_service.update!(ledgers_imported_at: Time.zone.now)
  end

  def fetch_balance_sheet(report_service:, date:, qbo_authorization:)
    start_date = Date.new(date.year, date.month, 1)
    end_date = Date.new(date.year, date.month, -1)
    Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: Quickbooks::BalanceSheetGeneralLedger,
      start_date: start_date, end_date: end_date,
      qbo_authorization: qbo_authorization
    )
  end

  def fetch_general_ledger(report_service:, start_date:, end_date:, qbo_authorization:)  # rubocop:disable Metrics/MethodLength
    Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: Quickbooks::CommonGeneralLedger,
      start_date: start_date, end_date: end_date,
      qbo_authorization: qbo_authorization
    )
    Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: Quickbooks::BalanceSheetGeneralLedger,
      start_date: start_date, end_date: end_date,
      qbo_authorization: qbo_authorization
    )

    if report_service.reports.where(template_id: Report::DEPARTMENT_REPORT).present?
      Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: Quickbooks::ExpensesGeneralLedger,
        start_date: start_date, end_date: end_date,
        qbo_authorization: qbo_authorization
      )
      Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: Quickbooks::RevenueGeneralLedger,
        start_date: start_date, end_date: end_date,
        qbo_authorization: qbo_authorization
      )
    end

    if report_service.reports.where(template_id: Report::VENDOR_REPORT).present?
      Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: Quickbooks::VendorGeneralLedger,
        start_date: start_date, end_date: end_date,
        qbo_authorization: qbo_authorization
      )
    end

    return if report_service.reports.where(template_id: { '$in': [Report::REVENUE_ACCOUNTING_REPORT, Report::REVENUE_REPORT] }).blank?

    Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: Quickbooks::BankGeneralLedger,
      start_date: start_date, end_date: end_date,
      qbo_authorization: qbo_authorization
    )
    Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: Quickbooks::AccountsPayableGeneralLedger,
      start_date: start_date, end_date: end_date,
      qbo_authorization: qbo_authorization
    )
  end
end
