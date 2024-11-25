# frozen_string_literal: true

require 'rails_helper'

module ItemValues
  module ItemActualsValue # rubocop:disable Metrics/ModuleLength
    RSpec.describe ItemYtdActualsValueCreator do
      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
      let(:report) { Report.create!(report_service: report_service, template_id: 'operators_operating_statement', name: 'report') }
      let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
      let(:metric_item) do
        parent_item.child_items.create!(name: 'metric_item', order: 1, identifier: 'metric_item', type_config: { 'name' => Item::TYPE_METRIC })
      end
      let(:child_item1) do
        item = parent_item.child_items.create!(name: 'child_item1', order: 1, identifier: 'child_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                               values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')))
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item
      end
      let(:child_item2) do
        item = parent_item.child_items.create!(name: 'child_item2', order: 1, identifier: 'child_item2', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item.item_accounts.create!(chart_of_account_id: 1003)
        item
      end
      let(:child_item3) do
        item = parent_item.child_items.create!(name: 'child_item3', order: 1, identifier: 'child_item3', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
        item.item_accounts.create!(chart_of_account_id: 1001)
        item
      end

      let(:bs_prior_day_child_item) do
        item = parent_item.child_items.create!(name: 'bs_prior_day_child_item', order: 1, identifier: 'bs_prior_day_child_item',
                                               type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER, 'calculation_type' => Item::BS_PRIOR_DAY_CALCULATION_TYPE },
                                               values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')))
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item
      end

      let(:current_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:ytd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
      let(:item_values) do
        [
          {
            item_id: child_item1.id.to_s,
            column_id: ytd_actual_column.id.to_s,
            item_identifier: 'child_item1',
            accumulated_value: 10.0,
            value: 20.0
          },
          {
            item_id: child_item1.id.to_s,
            column_id: current_actual_column.id.to_s,
            item_identifier: 'child_item1',
            accumulated_value: 10.0,
            value: 20.0
          }
        ]
      end
      let(:dependent_report_item_values) do
        [
          {
            item_id: dependent_report_child_item1.id.to_s,
            column_id: dependent_report_current_actual_column.id.to_s,
            item_identifier: 'child_item1',
            accumulated_value: 70.0,
            value: 60.0
          }
        ]
      end
      let(:previous_month_report_data) do
        report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2020-02-01', end_date: '2020-02-28', item_values: item_values)
      end
      let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2020-03-01', end_date: '2020-03-31') }

      let(:dependent_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'report') }
      let(:dependent_report_current_actual_column) { dependent_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:dependent_report_ytd_actual_column) { dependent_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
      let(:dependent_report_parent_item) do
        dependent_report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, totals: true)
      end
      let(:dependent_report_child_item1) do
        item = dependent_report_parent_item.child_items.create!(name: 'child_item1', order: 1, identifier: 'child_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                                                values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')))
        item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1001)
        item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1002)
        item
      end
      let(:dependent_report_child_item2) do
        item = dependent_report_parent_item.child_items.create!(name: 'child_item2', order: 1, identifier: 'child_item2',
                                                                type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, negative: true)
        item.item_accounts.create!(accounting_class_id: 2, chart_of_account_id: 1001)
        item.item_accounts.create!(accounting_class_id: 2, chart_of_account_id: 1002)
        item.item_accounts.create!(accounting_class_id: 2, chart_of_account_id: 1003)
        item
      end
      let(:dependent_report_data) do
        dependent_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: dependent_report_item_values)
      end
      let(:dependent_report_datas) { { 'owners_operating_statement' => dependent_report_data } }

      let(:common_general_ledger) do
        ::Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: report_data.start_date,
                                                  end_date: report_data.end_date)
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
      let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'Account1') }
      let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'Account2') }
      let(:accounting_classes) { [accounting_class1, accounting_class2] }

      describe '#call' do
        subject(:create_item_value) do
          described_class.new(
            report_data: report_data,
            item: current_item,
            column: ytd_actual_column,
            budgets: [],
            standard_metrics: [],
            dependent_report_datas: {},
            previous_month_report_data: pre_month_report_data,
            previous_year_report_data: nil,
            january_report_data_of_current_year: january_report_data,
            all_business_chart_of_accounts: [],
            all_business_vendors: [],
            accounting_classes: [],
            qbo_ledgers: qbo_ledgers
          ).call
        end

        before do
          child_item1
          child_item2
          qbo_general_ledger_line_item_details_body = file_fixture('qbo_general_ledger_line_item_details.json').read
          ::Quickbooks::GeneralLedgerAnalyzer.analyze(general_ledger: common_general_ledger, line_item_details_raw_data: qbo_general_ledger_line_item_details_body)
        end

        context 'when calculation_type is default' do
          let(:current_item) { child_item1 }
          let(:qbo_ledgers) { { Quickbooks::CommonGeneralLedger => common_general_ledger } }
          let(:pre_month_report_data) { previous_month_report_data }
          let(:january_report_data) { nil }

          it 'creates item_value for RANGE_YTD column' do
            report_data.item_values.create!(item_id: child_item1.id.to_s, column_id: current_actual_column.id.to_s, item_identifier: child_item1.identifier)
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item1.id.to_s, column_id: ytd_actual_column.id.to_s)
            expect(item_value.value).to eq(20.0)
            expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
          end
        end

        context 'when enabled_blank_value_for_metric option of report is true' do
          before { report.update!(enabled_blank_value_for_metric: true) }

          let(:current_item) { metric_item }
          let(:qbo_ledgers) { {} }
          let(:pre_month_report_data) { previous_month_report_data }
          let(:january_report_data) { nil }

          it 'creates item_value for RANGE_YTD column' do
            create_item_value
            item_value = report_data.item_values.find_by(item_id: metric_item.id.to_s, column_id: ytd_actual_column.id.to_s)
            expect(item_value.value).to be_nil
          end
        end

        context 'when calculation_type is Item::BS_PRIOR_DAY_CALCULATION_TYPE' do
          let(:current_item) { bs_prior_day_child_item }
          let(:qbo_ledgers) do
            {
              Quickbooks::BalanceSheetGeneralLedger => {
                current_period: common_general_ledger,
                previous_period: common_general_ledger
              }
            }
          end
          let(:pre_month_report_data) { nil }
          let(:january_report_data) { previous_month_report_data }

          it 'creates item_value for TYPE_QUICKBOOKS_LEDGER(BS_PRIOR_DAY_CALCULATION_TYPE) RANGE_YTD column' do # rubocop:disable RSpec/ExampleLength
            item_value = ItemGeneralLedgerActualsValueCreator.new(
              report_data: previous_month_report_data,
              item: bs_prior_day_child_item,
              column: current_actual_column,
              budgets: [],
              standard_metrics: [],
              dependent_report_datas: {},
              previous_month_report_data: nil,
              previous_year_report_data: nil,
              january_report_data_of_current_year: nil,
              all_business_chart_of_accounts: [],
              all_business_vendors: [],
              accounting_classes: [],
              qbo_ledgers: {
                Quickbooks::BalanceSheetGeneralLedger => {
                  current_period: common_general_ledger,
                  previous_period: common_general_ledger
                }
              }
            ).call
            item_value.update!(value: 20.0)

            create_item_value
            item_value = report_data.item_values.find_by(item_id: bs_prior_day_child_item.id.to_s, column_id: ytd_actual_column.id.to_s)
            expect(item_value.value).to eq(20.0)
          end
        end
      end
    end
  end
end
