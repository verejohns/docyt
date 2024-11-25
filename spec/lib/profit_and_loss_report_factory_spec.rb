# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfitAndLossReportFactory do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
  end

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: (Time.zone.today - 1.month))
  end
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: business_id, chart_of_account_id: 1001, qbo_id: '60', name: 'name1', acc_type_name: 'Expenses', parent_id: nil)
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: business_id, chart_of_account_id: 1002, qbo_id: '95', name: 'name2', acc_type_name: 'Expenses', parent_id: 1001)
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1003, qbo_id: '101', name: 'name3', acc_type_name: 'Expenses', parent_id: 1001)
  end
  let(:business_chart_of_accounts) { [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3] }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new(business_chart_of_accounts) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'class01', parent_external_id: nil) }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'class02', parent_external_id: nil) }
  let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: business_id, external_id: '5', parent_external_id: '1') }
  let(:accounting_classes) { [accounting_class1, accounting_class2, sub_class] }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new(accounting_classes) }
  let(:business_cloud_service_authorization) { Struct.new(:id, :uid, :second_token).new(id: 1, uid: '46208160000', second_token: 'qbo_access_token') }
  let(:business_quickbooks_connection_info) { instance_double(DocytServerClient::BusinessQboConnection, cloud_service_authorization: business_cloud_service_authorization) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business: business_info,
                    get_all_business_chart_of_accounts: business_chart_of_accounts_response,
                    get_accounting_classes: accounting_class_response,
                    get_qbo_connection: business_quickbooks_connection_info)
  end
  let(:item_value_factory) { instance_double(ItemValueFactory, generate_batch: true) }
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }

  describe '#create' do
    subject(:create_report) { described_class.create(report_service: report_service) }

    it 'creates a new report with items and columns' do
      expect(create_report).to be_success
      expect(create_report.report).not_to be_nil
    end
  end

  xdescribe '#create & refill_report' do
    subject(:create_report) { described_class.create(report_service: report_service) }

    before do
      general_ledgers_body = file_fixture('staging_mycool_general_ledger.json').read
      report_service.general_ledgers.create!(JSON.parse(general_ledgers_body))
      report_service.general_ledgers.all.each do |general_ledger|
        general_ledger.update!(_type: Quickbooks::ProfitAndLossGeneralLedger.to_s)
      end
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    end

    let(:business_api_instance) do
      instance_double(DocytServerClient::BusinessApi,
                      get_business: business_info,
                      get_all_business_chart_of_accounts: business_chart_of_accounts_response,
                      get_accounting_classes: accounting_class_response,
                      get_qbo_connection: business_quickbooks_connection_info)
    end
    let(:business_chart_of_accounts) do
      JSON.parse(
        file_fixture('staging_mycool_chart_of_accounts.json').read,
        object_class: Struct.new(:id, :business_id, :chart_of_account_id, :qbo_id, :qbo_error,
                                 :display_name, :name, :parent_id, :acc_type_name, :acc_type, :mapped_class_ids)
      )
    end
    let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new(business_chart_of_accounts) }
    let(:accounting_classes) do
      JSON.parse(file_fixture('staging_mycool_accounting_classes.json').read,
                 object_class: Struct.new(:id, :business_id, :name, :external_id, :parent_external_id))
    end
    let(:accounting_class_response) { Struct.new(:accounting_classes).new(accounting_classes) }
    let(:business_cloud_service_authorization) { Struct.new(:id, :uid, :second_token).new(id: 1, uid: '46208160000', second_token: 'qbo_access_token') }
    let(:business_quickbooks_connection_info) do
      instance_double(DocytServerClient::BusinessQboConnection,
                      cloud_service_authorization: business_cloud_service_authorization)
    end
    let(:business_response) { instance_double(DocytServerClient::Business, id: business_id) }
    let(:business_info) { Struct.new(:business).new(business_response) }

    it 'creates a new report with items and columns' do
      expect(create_report).to be_success
      described_class.refill_report(report: create_report.report)
    end
  end
end
