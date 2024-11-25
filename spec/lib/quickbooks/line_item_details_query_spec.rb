# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quickbooks::LineItemDetailsQuery do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(DocytServerClient::ReportServiceApi).to receive(:new).and_return(report_api_instance)
  end

  let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }

  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '101', display_name: 'name1')
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: 105, chart_of_account_id: 1002, qbo_id: '102', display_name: 'name2')
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1003, qbo_id: '103', display_name: 'name3')
  end
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
  let(:business_vendor1) do
    instance_double(DocytServerClient::BusinessVendor,
                    id: 1, business_id: 105, vendor_id: 1001, qbo_id: '60', name: 'item', qbo_name: 'item')
  end
  let(:business_vendor2) do
    instance_double(DocytServerClient::BusinessVendor,
                    id: 2, business_id: 105, vendor_id: 1002, qbo_id: '95', name: 'item2', qbo_name: 'item2')
  end
  let(:business_vendors) { Struct.new(:business_vendors).new([business_vendor1, business_vendor2]) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4') }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1') }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new([accounting_class1, accounting_class2]) }
  let(:business_api_instance) do
    instance_double(
      DocytServerClient::BusinessApi,
      get_all_business_chart_of_accounts: business_chart_of_accounts_response,
      get_all_business_vendors: business_vendors,
      get_accounting_classes: accounting_class_response
    )
  end
  let(:report_api_instance) do
    instance_double(
      DocytServerClient::ReportServiceApi,
      get_account_value_links: []
    )
  end
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'name1') }
  let(:start_date) { '2022-08-01' }
  let(:end_date) { '2022-08-31' }

  describe '#by_period without total' do
    subject(:line_item_details_by_period) { described_class.new(report: report, item: item, params: params).by_period(start_date: start_date, end_date: end_date) }

    before do
      general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-01', amount: 10.0, chart_of_account_qbo_id: '105', accounting_class_qbo_id: '2')
      general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-02', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '1')
      general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-03', amount: 10.0, chart_of_account_qbo_id: '102', accounting_class_qbo_id: nil)
      general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-04', amount: 10.0, chart_of_account_qbo_id: '104', accounting_class_qbo_id: '4',
                                                                         transaction_type: 'Bill Payment (Check)', qbo_id: '149')
      general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
        transaction_date: '2022-08-05', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: nil,
        transaction_type: 'Bill Payment (Check)', qbo_id: '150'
      )
      general_ledger.save!

      expenses_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
        transaction_date: '2022-08-01', amount: 10.0,
        chart_of_account_qbo_id: '105',
        accounting_class_qbo_id: '2'
      )
      expenses_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
        transaction_date: '2022-08-02', amount: 10.0,
        chart_of_account_qbo_id: '101',
        accounting_class_qbo_id: '1'
      )
      expenses_general_ledger.save!
    end

    let(:item) { report.items.create!(name: 'item', order: 1, identifier: 'item') }
    let(:general_ledger) { Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31') }
    let(:expenses_general_ledger) { Quickbooks::ExpensesGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31') }

    context 'without chart_of_account_id and accounting_class_id' do
      let(:params) { {} }

      it 'contains 5 line_item_details' do
        expect(line_item_details_by_period.length).to eq(5)
      end
    end

    context 'with chart_of_account_id and accounting_class_id' do
      let(:params) { { chart_of_account_id: 1001 } }

      it 'only contains 1 line item details' do
        expect(line_item_details_by_period.length).to eq(1)
      end
    end

    context 'with chart_of_account_id' do
      let(:params) { { chart_of_account_id: 1001 } }

      it 'does not check accounting_class_id' do
        report.update!(accounting_class_check_disabled: true)
        expect(line_item_details_by_period.length).to eq(2)
      end
    end

    context 'with departmental report item' do
      let(:params) { {} }
      let(:report) { Report.create!(report_service: report_service, template_id: 'departmental_report', name: 'name1') }
      let(:item) { report.items.create!(name: 'item', order: 1, identifier: 'item') }

      it 'contains 2 expense line_item_details' do
        expect(line_item_details_by_period.length).to eq(2)
      end
    end

    context 'with vendor report item' do
      before do
        vendor_general_ledger.line_item_details.create!(transaction_type: 'Bill Payment (Check)', qbo_id: '1001', amount: 10.0, chart_of_account_qbo_id: '101', vendor: 'item')
      end

      let(:vendor_general_ledger) do
        ::Quickbooks::VendorGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31')
      end
      let(:params) { { chart_of_account_id: 1001 } }

      it 'only contains 1 line item details from bank_general_ledger' do
        report.update(template_id: Report::VENDOR_REPORT)
        item.type_config = {}
        item.type_config[Item::CALCULATION_TYPE_CONFIG] = Item::GENERAL_LEDGER_CALCULATION_TYPE
        line_item_details = line_item_details_by_period
        expect(line_item_details.length).to eq(1)
        expect(line_item_details[0].id).to eq(vendor_general_ledger.line_item_details.first.id)
      end
    end

    context 'with Item::BANK_GENERAL_LEDGER_CALCULATION_TYPE item' do
      before do
        bank_general_ledger.line_item_details.create!(transaction_type: 'Bill Payment (Check)', qbo_id: '150', amount: 10.0)
      end

      let(:bank_general_ledger) do
        ::Quickbooks::BankGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31')
      end
      let(:params) { { chart_of_account_id: 1001 } }

      it 'only contains 1 line item details from bank_general_ledger' do
        item.type_config = {}
        item.type_config[Item::CALCULATION_TYPE_CONFIG] = Item::BANK_GENERAL_LEDGER_CALCULATION_TYPE
        line_item_details = line_item_details_by_period
        expect(line_item_details.length).to eq(1)
        expect(line_item_details[0].id).to eq(bank_general_ledger.line_item_details.first.id)
      end
    end

    context 'with Item::TAX_COLLECTED_VALUE_CALCULATION_TYPE item' do
      before do
        bank_general_ledger.line_item_details.create!(transaction_type: 'Bill Payment (Check)', qbo_id: '150', amount: 10.0)
        ap_general_ledger.line_item_details.create!(transaction_type: 'Bill Payment (Check)', qbo_id: '149', amount: 10.0)
      end

      let(:bank_general_ledger) do
        ::Quickbooks::BankGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31',
                                                chart_of_account_qbo_id: '101', accounting_class_qbo_id: nil)
      end
      let(:ap_general_ledger) do
        ::Quickbooks::AccountsPayableGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31',
                                                           chart_of_account_qbo_id: '101', accounting_class_qbo_id: nil)
      end
      let(:params) { {} }

      it 'contains 5 line item details from bank_general_ledger' do
        item.type_config = {}
        item.type_config[Item::CALCULATION_TYPE_CONFIG] = Item::TAX_COLLECTED_VALUE_CALCULATION_TYPE
        line_item_details = line_item_details_by_period
        expect(line_item_details.length).to eq(5)
        expect(line_item_details[0].id).to eq(general_ledger.line_item_details.first.id)
      end

      it 'only contains 4 line item details from bank_general_ledger and ap_general_ledger' do
        item.type_config = {}
        item.type_config[Item::CALCULATION_TYPE_CONFIG] = Item::TAX_COLLECTED_VALUE_CALCULATION_TYPE
        item.type_config[Item::EXCLUDE_LEDGERS_CONFIG] = Item::EXCLUDE_LEDGERS_BANK_AND_AP
        line_item_details = line_item_details_by_period
        expect(line_item_details.length).to eq(4)
        expect(line_item_details[0].id).to eq(general_ledger.line_item_details.first.id)
      end
    end
  end

  describe '#by_period with total' do
    subject(:line_item_details_by_period) do
      described_class.new(report: report, item: item, params: params).by_period(
        start_date: start_date, end_date: end_date, include_total: true
      )
    end

    context 'without chart_of_account_id and accounting_class_id' do
      let(:params) { {} }
      let(:item) { report.items.create!(name: 'item', order: 1, identifier: 'item', type_config: { 'calculation_type' => Item::BS_BALANCE_CALCULATION_TYPE }) }
      let(:general_ledger) { Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31') }

      it 'contains 2 line_item_details' do
        expect(line_item_details_by_period.length).to eq(2)
      end
    end

    context 'with chart_of_account_id and accounting_class_id' do
      before do
        general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-01',
                                                                           amount: 10.0, chart_of_account_qbo_id: '105', accounting_class_qbo_id: '2')
        general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-02',
                                                                           amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '1')
        general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-03',
                                                                           amount: 10.0, chart_of_account_qbo_id: '102', accounting_class_qbo_id: nil)
        general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-04',
                                                                           amount: 10.0, chart_of_account_qbo_id: '104', accounting_class_qbo_id: '4')
        general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-05', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: nil,
          transaction_type: 'Bill Payment (Check)', qbo_id: '150'
        )
        general_ledger.save!

        previous_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-07-02',
                                                                                    amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '1')
        previous_general_ledger.save!
      end

      let(:params) { { chart_of_account_id: 1001 } }
      let(:item) { report.items.create!(name: 'item', order: 1, identifier: 'item', type_config: { 'calculation_type' => Item::BS_BALANCE_CALCULATION_TYPE }) }
      let(:previous_general_ledger) { Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service, start_date: '2022-07-01', end_date: '2022-07-31') }
      let(:general_ledger) { Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31') }

      it 'only contains 1 line item details' do
        expect(line_item_details_by_period.length).to eq(3)
      end
    end
  end
end
