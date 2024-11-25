# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportFactory do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
  end

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'operators_operating_statement', name: 'name1') }
  let(:revenue_report) { Report.create!(report_service: report_service, template_id: 'revenue_report', name: 'Revenue Report') }
  let(:bookkeeping_start_date) { Time.zone.today }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: bookkeeping_start_date)
  end
  let(:business_response2) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: bookkeeping_start_date)
  end
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_info2) { Struct.new(:business).new(business_response2) }
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
  let(:business_chart_of_accounts) { [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3] }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new(business_chart_of_accounts) }
  let(:business_vendors_response) { Struct.new(:business_vendors).new([]) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'class01', parent_external_id: nil) }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'class02', parent_external_id: nil) }
  let(:report_dependency) { instance_double(ReportDependencies::Base, has_changed?: false) }
  let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: business_id, external_id: '5', parent_external_id: '1') }
  let(:accounting_classes) { [accounting_class1, accounting_class2, sub_class] }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new(accounting_classes) }
  let(:business_cloud_service_authorization) { Struct.new(:id, :uid, :second_token).new(id: 1, uid: '46208160000', second_token: 'qbo_access_token') }
  let(:business_quickbooks_connection_info) { instance_double(DocytServerClient::BusinessQboConnection, cloud_service_authorization: business_cloud_service_authorization) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business: business_info,
                    get_all_business_chart_of_accounts: business_chart_of_accounts_response,
                    get_all_business_vendors: business_vendors_response,
                    get_accounting_classes: accounting_class_response,
                    get_qbo_connection: business_quickbooks_connection_info)
  end
  let(:business_api_instance2) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business: business_info2,
                    get_all_business_chart_of_accounts: business_chart_of_accounts_response,
                    get_all_business_vendors: business_vendors_response,
                    get_accounting_classes: accounting_class_response,
                    get_qbo_connection: business_quickbooks_connection_info)
  end
  let(:item_value_factory) { instance_double(ItemValueFactory, generate_batch: true) }
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }
  let(:daily_report_data) { create(:report_data, report: report, start_date: '2022-03-01', end_date: '2022-03-01', period_type: ReportData::PERIOD_DAILY) }

  describe '#update' do
    let(:report_param) do
      {
        report_service_id: report_service.service_id,
        template_id: 'owners_operating_statement',
        name: 'name',
        user_ids: [1],
        accepted_accounting_class_ids: [1],
        accepted_account_types: [{ account_type: 'test', account_detail_type: 'test' }]
      }
    end

    it 'update report' do
      result = described_class.update(report: report, report_params: report_param)
      expect(result).to be_success
    end
  end

  describe '#enqueue_report_update' do
    let(:report_param) do
      {
        report_service_id: report_service.service_id,
        template_id: 'owners_operating_statement',
        name: 'name'
      }
    end

    it 'refreshes report' do
      expect do
        described_class.enqueue_report_update(report)
      end.to change { DocytLib.async.event_queue.size }.by(1)
      expect(DocytLib.async.event_queue.events.last.priority).to eq(ReportFactory::MANUAL_UPDATE_PRIORITY)
    end
  end

  describe '#enqueue_report_data_update' do
    it 'fires event to refresh report' do
      expect do
        described_class.enqueue_report_data_update(daily_report_data)
      end.to change { DocytLib.async.event_queue.size }.by(1)
    end
  end

  describe '#refill_daily_report_data' do
    before do
      allow(ItemValueFactory).to receive(:new).and_return(item_value_factory)
      allow(Quickbooks::GeneralLedgerImporter).to receive(:new).and_return(general_ledger_importer)
      allow(Quickbooks::GeneralLedgerAnalyzer).to receive(:new).and_return(general_ledger_analyzer)
      allow(Quickbooks::BalanceSheetAnalyzer).to receive(:new).and_return(balance_sheet_analyzer)
    end

    let(:qbo_token) { Struct.new(:id, :uid, :second_token).new(1, SecureRandom.uuid, Faker::Lorem.characters(number: 32)) }
    let(:general_ledger_importer) { instance_double(Quickbooks::GeneralLedgerImporter, import: true, fetch_qbo_token: qbo_token) }
    let(:general_ledger_analyzer) { instance_double(Quickbooks::GeneralLedgerAnalyzer, analyze: true) }
    let(:balance_sheet_analyzer) { instance_double(Quickbooks::BalanceSheetAnalyzer, analyze: true) }
    let(:report_data1) do
      create(:report_data,
             report: revenue_report,
             start_date: Time.zone.now.at_beginning_of_month,
             end_date: Time.zone.now.at_beginning_of_month,
             period_type: ReportData::PERIOD_DAILY)
    end

    it 'does not rebuild when dependencies have not changed' do
      allow_any_instance_of(described_class).to receive(:should_update).and_return(false) # rubocop:disable RSpec/AnyInstance
      expect_any_instance_of(described_class).not_to receive(:fill_report_data) # rubocop:disable RSpec/AnyInstance
      described_class.refill_daily_report_data(report_data: report_data1)
    end

    it 'calls ItemValueFactory' do
      report_data1
      described_class.refill_daily_report_data(report_data: report_data1)
      expect(item_value_factory).to have_received(:generate_batch).once
    end
  end

  describe '#refill_report' do
    before do
      allow(ItemValueFactory).to receive(:new).and_return(item_value_factory)
    end

    let(:report_data1) do
      create(:report_data,
             report: report,
             start_date: Time.zone.now.at_beginning_of_month - 1.month,
             end_date: Time.zone.now.at_beginning_of_month - 1.day,
             period_type: ReportData::PERIOD_MONTHLY)
    end

    let(:report_data2) do
      create(:report_data, report: report, start_date: Time.zone.now.at_beginning_of_month, end_date: Time.zone.now.end_of_month, period_type: ReportData::PERIOD_MONTHLY)
    end

    it 'syncs report informations' do
      result = described_class.refill_report(report: report)
      expect(result).to be_success
    end

    it 'generates report_datas' do
      expect do
        result = described_class.refill_report(report: report)
        expect(result).to be_success
      end.to change(ReportData, :count).by(Time.zone.today.month)
    end

    it 'calls ItemValueFactory' do
      report_data1
      report_data2
      described_class.refill_report(report: report)
      expect(item_value_factory).to have_received(:generate_batch).exactly(Time.zone.today.month).times
    end

    it 'does not call ItemValueFactory when dependencies has not changed' do
      report_data1
      report_data2
      allow(ReportDependencies::Base).to receive(:new).and_return(report_dependency)
      described_class.refill_report(report: report)
      expect(item_value_factory).not_to have_received(:generate_batch)
    end

    it 'does not create existing item, only update items' do
      report.update!(template_id: Report::DEPARTMENT_REPORT)
      described_class.refill_report(report: report)
      revenue_parent_item = report.items.find_by(identifier: Item::REVENUE)
      before_revenue_child_item = revenue_parent_item.child_items.find_by(identifier: "#{Item::REVENUE}_#{accounting_class1.id}")
      described_class.refill_report(report: report)
      revenue_parent_item = report.items.find_by(identifier: Item::REVENUE)
      after_revenue_child_item = revenue_parent_item.child_items.find_by(identifier: "#{Item::REVENUE}_#{accounting_class1.id}")
      expect(report.template_id).to eq(Report::DEPARTMENT_REPORT)
      expect(report.items[0].identifier).to eq(Item::REVENUE)
      expect(after_revenue_child_item.id).to eq(before_revenue_child_item.id)
    end

    it 'updates report_datas from 1st jan of year' do
      start_date = Date.new(bookkeeping_start_date.year, 1, 1)
      described_class.refill_report(report: report)
      expect(ReportData.first.start_date).to eq(start_date)
    end
  end
end
