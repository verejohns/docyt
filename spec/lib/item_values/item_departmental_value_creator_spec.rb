# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemDepartmentalValueCreator do
    before do
      department_column
      department_report_items = JSON.parse(file_fixture('department_report_items.json').read)
      department_report.update!(items: department_report_items)
      expenses_general_ledger_body = file_fixture('expenses_general_ledger.json').read
      expenses_general_ledger.update!(JSON.parse(expenses_general_ledger_body))
      revenue_general_ledger_body = file_fixture('revenue_general_ledger.json').read
      revenue_general_ledger.update!(JSON.parse(revenue_general_ledger_body))
    end

    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:department_report) { Report.create!(report_service: report_service, template_id: Report::DEPARTMENT_REPORT, name: 'report') }
    let(:department_column) { department_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:department_report_data) do
      department_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-07-01', end_date: '2021-07-31')
    end
    let(:expenses_general_ledger) do
      ::Quickbooks::ExpensesGeneralLedger.create!(report_service: report_service, start_date: department_report_data.start_date,
                                                  end_date: department_report_data.end_date)
    end
    let(:revenue_general_ledger) do
      ::Quickbooks::RevenueGeneralLedger.create!(report_service: report_service, start_date: department_report_data.start_date,
                                                 end_date: department_report_data.end_date)
    end

    let(:business_chart_of_accounts) do
      JSON.parse(
        file_fixture('business_chart_of_accounts.json').read,
        object_class: Struct.new(:id, :business_id, :chart_of_account_id, :qbo_id, :qbo_error, :display_name, :parent_id, :mapped_class_ids, :acc_type)
      )
    end
    let(:accounting_classes) { JSON.parse(file_fixture('accounting_classes.json').read, object_class: Struct.new(:id, :business_id, :name, :external_id, :parent_external_id)) }

    describe '#call' do
      it 'creates revenue item_value' do
        revenue_child_item = department_report.find_item_by_identifier(identifier: 'revenue_5000000000000145595')
        item_value = described_class.new(
          report_data: department_report_data,
          item: revenue_child_item,
          column: department_column,
          budgets: [],
          standard_metrics: [],
          dependent_report_datas: [],
          previous_month_report_data: nil,
          previous_year_report_data: nil,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: business_chart_of_accounts,
          all_business_vendors: [],
          accounting_classes: accounting_classes,
          qbo_ledgers: {
            Quickbooks::RevenueGeneralLedger => revenue_general_ledger,
            Quickbooks::ExpensesGeneralLedger => expenses_general_ledger
          }
        ).call
        expect(item_value.value).to eq(14_807.04)
      end

      it 'creates expense item_value' do
        expense_child_item = department_report.find_item_by_identifier(identifier: 'expenses_5000000000000145595')
        item_value = described_class.new(
          report_data: department_report_data,
          item: expense_child_item,
          column: department_column,
          budgets: [],
          standard_metrics: [],
          dependent_report_datas: [],
          previous_month_report_data: nil,
          previous_year_report_data: nil,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: business_chart_of_accounts,
          all_business_vendors: [],
          accounting_classes: accounting_classes,
          qbo_ledgers: {
            Quickbooks::RevenueGeneralLedger => revenue_general_ledger,
            Quickbooks::ExpensesGeneralLedger => expenses_general_ledger
          }
        ).call
        expect(item_value.value).to eq(14_807.04)
      end

      it 'creates profit item_value' do
        profit_child_item = department_report.find_item_by_identifier(identifier: 'profit_5000000000000145595')
        item_value = described_class.new(
          report_data: department_report_data,
          item: profit_child_item,
          column: department_column,
          budgets: [],
          standard_metrics: [],
          dependent_report_datas: [],
          previous_month_report_data: nil,
          previous_year_report_data: nil,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: business_chart_of_accounts,
          all_business_vendors: [],
          accounting_classes: accounting_classes,
          qbo_ledgers: {
            Quickbooks::RevenueGeneralLedger => revenue_general_ledger,
            Quickbooks::ExpensesGeneralLedger => expenses_general_ledger
          }
        ).call
        expect(item_value.value).to eq(0.0)
      end
    end
  end
end
