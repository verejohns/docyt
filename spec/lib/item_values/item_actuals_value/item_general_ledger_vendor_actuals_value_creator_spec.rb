# frozen_string_literal: true

require 'rails_helper'

module ItemValues
  module ItemActualsValue
    RSpec.describe ItemGeneralLedgerVendorActualsValueCreator do
      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
      let(:report) { Report.create!(report_service: report_service, template_id: 'vendor_report', name: 'report') }
      let(:child_item) { report.items.create!(name: 'vendor_name1', order: 2, identifier: 'vendor_name1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }

      let(:current_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:mtd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_MTD, year: Column::YEAR_CURRENT) }
      let(:item_values) do
        [
          {
            item_id: child_item.id.to_s,
            column_id: current_actual_column.id.to_s,
            item_identifier: 'child_item1',
            accumulated_value: 10.0,
            value: 20.0
          }
        ]
      end

      let(:previous_month_report_data) do
        report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2020-02-01', end_date: '2020-02-28', item_values: item_values)
      end
      let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2020-03-01', end_date: '2020-03-31') }

      let(:vendor_general_ledger) do
        ::Quickbooks::VendorGeneralLedger.create!(report_service: report_service, start_date: report_data.start_date, end_date: report_data.end_date)
      end

      let(:business_chart_of_account1) do
        instance_double(DocytServerClient::BusinessChartOfAccount,
                        id: 1, business_id: business_id, chart_of_account_id: 1001, qbo_id: '101', display_name: 'name1', acc_type: 'Expense')
      end
      let(:business_chart_of_account2) do
        instance_double(DocytServerClient::BusinessChartOfAccount,
                        id: 2, business_id: business_id, chart_of_account_id: 1002, qbo_id: '90', display_name: 'name2', acc_type: 'Expense')
      end
      let(:business_chart_of_account3) do
        instance_double(DocytServerClient::BusinessChartOfAccount,
                        id: 3, business_id: business_id, chart_of_account_id: 1003, qbo_id: '60', display_name: 'name3', acc_type: 'Expense')
      end
      let(:business_chart_of_accounts) { [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3] }
      let(:business_vendor1) do
        instance_double(DocytServerClient::BusinessVendor,
                        id: 1, business_id: business_id, vendor_id: 1001, qbo_id: '60', name: 'vendor_name1', qbo_name: 'DIRECTV')
      end
      let(:business_vendor2) do
        instance_double(DocytServerClient::BusinessVendor,
                        id: 2, business_id: business_id, vendor_id: 1002, qbo_id: '95', name: 'vendor_name2', qbo_name: 'DIRECTV NONE')
      end
      let(:business_vendors) { [business_vendor1, business_vendor2] }
      let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'Account1') }
      let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'Account2') }
      let(:accounting_classes) { [accounting_class1, accounting_class2] }

      describe '#call' do
        subject(:create_item_value) do
          described_class.new(
            report_data: report_data,
            item: child_item,
            column: current_actual_column,
            budgets: [],
            standard_metrics: [],
            dependent_report_datas: {},
            previous_month_report_data: previous_month_report_data,
            previous_year_report_data: nil,
            january_report_data_of_current_year: nil,
            all_business_chart_of_accounts: business_chart_of_accounts,
            all_business_vendors: business_vendors,
            accounting_classes: accounting_classes,
            qbo_ledgers: qbo_ledgers
          ).call
        end

        before do
          general_ledger_line_item_details_body = file_fixture('qbo_general_ledger_line_item_details.json').read
          ::Quickbooks::GeneralLedgerAnalyzer.analyze(general_ledger: vendor_general_ledger, line_item_details_raw_data: general_ledger_line_item_details_body)
        end

        context 'when qbo_ledger is VendorGeneralLedger' do
          let(:qbo_ledgers) { {} }

          it 'creates item_value for TYPE_QUICKBOOKS_LEDGER item and RANGE_CURRENT column' do
            report.update(template_id: Report::VENDOR_REPORT)
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(-3782.12)
            expect(item_value.accumulated_value).to eq(-3772.12)
            expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
            expect(item_value.item_account_values.count).to eq(0)
          end
        end
      end
    end
  end
end
