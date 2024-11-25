# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDataUpdater do
  before do
    allow(ReportFactory).to receive(:new).and_return(report_factory)
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(Quickbooks::GeneralLedgerImporter).to receive(:new).and_return(general_ledger_importer)
    allow(Quickbooks::GeneralLedgerAnalyzer).to receive(:new).and_return(general_ledger_analyzer)
    allow(Quickbooks::BalanceSheetAnalyzer).to receive(:new).and_return(balance_sheet_analyzer)
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }

  let(:owner_report) { create(:report, name: 'Owners Report', report_service: report_service, template_id: 'owners_operating_statement') }
  let(:report) { create(:report, name: 'Test Report', report_service: report_service, template_id: 'test_template', dependent_template_ids: ['owners_operating_statement']) }
  let(:departmental_report) { create(:report, name: 'Department Report', report_service: report_service, template_id: Report::DEPARTMENT_REPORT) }

  let(:report_factory) { instance_double(ReportFactory, refill_report: true, refill_daily_report_data: true) }
  let(:qbo_token) { Struct.new(:id, :uid, :second_token).new(1, SecureRandom.uuid, Faker::Lorem.characters(number: 32)) }
  let(:general_ledger_importer) { instance_double(Quickbooks::GeneralLedgerImporter, import: true, fetch_qbo_token: qbo_token) }
  let(:general_ledger_analyzer) { instance_double(Quickbooks::GeneralLedgerAnalyzer, analyze: true) }
  let(:balance_sheet_analyzer) { instance_double(Quickbooks::BalanceSheetAnalyzer, analyze: true) }

  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: (Time.zone.today - 1.month))
  end
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: business_id, chart_of_account_id: 1001, qbo_id: '60', display_name: 'name1')
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: business_id, chart_of_account_id: 1002, qbo_id: '95', display_name: 'name2')
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1003, qbo_id: '101', display_name: 'name3')
  end
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'class01', parent_external_id: nil) }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'class02', parent_external_id: nil) }
  let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: business_id, external_id: '5', parent_external_id: '1') }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new([accounting_class1, accounting_class2, sub_class]) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi, get_business: business_info)
  end

  let(:qbo_throttling_error) do
    response = double( # rubocop:disable RSpec/VerifiedDoubles
      parsed: {
        'Fault' => {
          'Error' => [{
            'code' => '3001',
            'Detail' => 'ERROR'
          }]
        }
      },
      status: 429
    ).as_null_object
    OAuth2::Error.new(response)
  end

  let(:daily_report_data) { create(:report_data, report: owner_report, start_date: '2022-03-01', end_date: '2022-03-01', period_type: ReportData::PERIOD_DAILY) }

  describe '#update_report_data' do
    subject(:update_report_data) { described_class.update_report_data(report_data: daily_report_data) }

    context 'when QBO is disconnected' do
      before do
        allow(general_ledger_importer).to receive(:fetch_qbo_token).and_return(nil)
      end

      it 'updates update_state and error_msg for the ReportData' do
        update_report_data
        expect(daily_report_data.update_state).to eq(Report::UPDATE_STATE_FAILED)
        expect(daily_report_data.error_msg).to eq(Report::ERROR_MSG_QBO_NOT_CONNECTED)
      end
    end

    context 'when standart error happens' do
      before do
        allow(report_factory).to receive(:refill_daily_report_data).and_raise(StandardError.new('standard error'))
      end

      it 'updates update_state and error_msg for owner report' do
        update_report_data
        expect(daily_report_data.update_state).to eq(Report::UPDATE_STATE_FAILED)
      end
    end
  end
end
