# frozen_string_literal: true

module ReportDependencies
  class Quickbooks < Base
    def calculate_digest
      general_ledgers = @report_data.report.report_service.general_ledgers
                                    .where(start_date: @report_data.general_ledger_start_date, end_date: @report_data.general_ledger_end_date)
                                    .sort_by(&:_type)
      line_item_details = general_ledgers.map do |general_ledger|
        general_ledger.line_item_details.sort_by(&:qbo_id)
      end.flatten
      DocytLib::Encryption::Digest.dataset_digest(line_item_details, %i[transaction_date chart_of_account_qbo_id accounting_class_qbo_id amount])
    end

    def refresh # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      return unless @report_data.daily?

      report = @report_data.report
      report_service = report.report_service
      qbo_authorization = ::Quickbooks::GeneralLedgerImporter.fetch_qbo_token(report_service)
      ::Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: ::Quickbooks::CommonGeneralLedger,
        start_date: @report_data.general_ledger_start_date,
        end_date: @report_data.general_ledger_end_date,
        qbo_authorization: qbo_authorization
      )
      ::Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: ::Quickbooks::BankGeneralLedger,
        start_date: @report_data.general_ledger_start_date,
        end_date: @report_data.general_ledger_end_date,
        qbo_authorization: qbo_authorization
      )
      ::Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: ::Quickbooks::AccountsPayableGeneralLedger,
        start_date: @report_data.general_ledger_start_date,
        end_date: @report_data.general_ledger_end_date,
        qbo_authorization: qbo_authorization
      )
      ::Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: ::Quickbooks::BalanceSheetGeneralLedger,
        start_date: @report_data.start_date,
        end_date: @report_data.end_date,
        qbo_authorization: qbo_authorization
      )
      ::Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: ::Quickbooks::BalanceSheetGeneralLedger,
        start_date: @report_data.start_date - 1.day,
        end_date: @report_data.end_date - 1.day,
        qbo_authorization: qbo_authorization
      )
      ::Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: ::Quickbooks::BalanceSheetGeneralLedger,
        start_date: @report_data.general_ledger_start_date,
        end_date: @report_data.end_date,
        qbo_authorization: qbo_authorization
      )
      ::Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: ::Quickbooks::BalanceSheetGeneralLedger,
        start_date: @report_data.general_ledger_start_date,
        end_date: @report_data.end_date - 1.day,
        qbo_authorization: qbo_authorization
      )
      return unless report.vendor_report?

      ::Quickbooks::GeneralLedgerImporter.import(
        report_service: report_service,
        general_ledger_class: ::Quickbooks::VendorGeneralLedger,
        start_date: @report_data.general_ledger_start_date,
        end_date: @report_data.general_ledger_end_date,
        qbo_authorization: qbo_authorization
      )
    end
  end
end
