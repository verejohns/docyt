# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemDepartmentBudgetActualsValueCreator do
    before do
      revenue_child_item
      expenses_child_item
      budget_items
    end

    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:department_report) { Report.create!(report_service: report_service, template_id: Report::DEPARTMENT_REPORT, name: 'report') }
    let(:revenue_parent_item) { department_report.items.create!(name: 'Revenue', order: 0, identifier: 'revenue') }
    let(:revenue_child_item) do
      item = revenue_parent_item.child_items.create!(name: 'revenue_child_item', order: 0, identifier: 'revenue_child_item',
                                                     type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
      item.item_accounts.create!(accounting_class_id: 1)
      item
    end
    let(:total_revenue_child_item) do
      item = revenue_child_item.child_items.create!(name: 'total_revenue_child_item', order: 0, identifier: 'total_revenue_child_item',
                                                    totals: true)
      item
    end
    let(:revenue_total_item) do
      revenue_parent_item.child_items.create!(name: 'total_revenue', order: 1, identifier: 'total_revenue', totals: true, type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
    end

    let(:expenses_parent_item) { department_report.items.create!(name: 'Expenses', order: 1, identifier: 'expenses') }
    let(:expenses_child_item) do
      item = expenses_parent_item.child_items.create!(name: 'expenses_child_item', order: 0, identifier: 'expenses_child_item',
                                                      type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
      item.item_accounts.create!(accounting_class_id: 1)
      item
    end
    let(:expenses_total_item) do
      expenses_parent_item.child_items.create!(name: 'total_expenses', order: 1, identifier: 'total_expenses', totals: true)
    end

    let(:profit_parent_item) { department_report.items.create!(name: 'Profit', order: 2, identifier: 'profit') }
    let(:profit_child_item) do
      item = profit_parent_item.child_items.create!(name: 'profit_child_item', order: 0, identifier: 'profit_child_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
      item.item_accounts.create!(accounting_class_id: 1)
      item
    end
    let(:profit_total_item) do
      profit_parent_item.child_items.create!(name: 'total_profit', order: 1, identifier: 'total_profit', totals: true)
    end

    let(:department_budget_actual_column) { department_report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:department_report_data) { department_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28') }

    let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4') }
    let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1') }
    let(:accounting_classes) { [accounting_class1, accounting_class2] }

    let(:business_chart_of_account1) { instance_double(DocytServerClient::BusinessChartOfAccount, id: 1, business_id: 105, chart_of_account_id: 1001, acc_type: 'Income') }
    let(:business_chart_of_account2) { instance_double(DocytServerClient::BusinessChartOfAccount, id: 2, business_id: 105, chart_of_account_id: 1002, acc_type: 'Expense') }
    let(:business_chart_of_account3) do
      instance_double(DocytServerClient::BusinessChartOfAccount, id: 3, business_id: 105, chart_of_account_id: 1003, acc_type: 'Cost of Goods Sold')
    end
    let(:all_business_chart_of_accounts) { [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3] }

    let(:budget_item_values) do
      [
        { month: 1, value: 10.0 },
        { month: 2, value: 10.0 },
        { month: 3, value: 10.0 },
        { month: 4, value: 10.0 },
        { month: 5, value: 10.0 },
        { month: 6, value: 10.0 },
        { month: 7, value: 10.0 },
        { month: 8, value: 10.0 },
        { month: 9, value: 10.0 },
        { month: 10, value: 10.0 },
        { month: 11, value: 10.0 },
        { month: 12, value: 10.0 }
      ]
    end
    let(:budget1) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget2) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget_items) do
      ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 1001, accounting_class_id: 1, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 1002, accounting_class_id: 1, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 1003, accounting_class_id: 1, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 1001, accounting_class_id: 1, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 1002, accounting_class_id: 1, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 1003, accounting_class_id: 1, budget_item_values: budget_item_values)
    end
    let(:budgets) { [budget1, budget2] }

    describe '#call' do
      it 'creates budget_values for revenue item' do
        item_value = described_class.new(
          report_data: department_report_data,
          item: revenue_child_item,
          column: department_budget_actual_column,
          budgets: budgets,
          standard_metrics: [],
          dependent_report_datas: [],
          previous_month_report_data: nil,
          previous_year_report_data: nil,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: all_business_chart_of_accounts,
          all_business_vendors: [],
          accounting_classes: accounting_classes,
          qbo_ledgers: {}
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(10.0)
      end

      it 'creates budget_values for expenses item' do
        item_value = described_class.new(
          report_data: department_report_data,
          item: expenses_child_item,
          column: department_budget_actual_column,
          budgets: budgets,
          standard_metrics: [],
          dependent_report_datas: [],
          previous_month_report_data: nil,
          previous_year_report_data: nil,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: all_business_chart_of_accounts,
          all_business_vendors: [],
          accounting_classes: accounting_classes,
          qbo_ledgers: {}
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(20.0)
      end

      it 'creates budget_values for profit item' do
        item_value = described_class.new(
          report_data: department_report_data,
          item: profit_child_item,
          column: department_budget_actual_column,
          budgets: budgets,
          standard_metrics: [],
          dependent_report_datas: [],
          previous_month_report_data: nil,
          previous_year_report_data: nil,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: all_business_chart_of_accounts,
          all_business_vendors: [],
          accounting_classes: accounting_classes,
          qbo_ledgers: {}
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(-10.0)
      end

      it 'creates total budget_values for revenue item' do
        total_revenue_child_item
        item_value = described_class.new(
          report_data: department_report_data,
          item: revenue_total_item,
          column: department_budget_actual_column,
          budgets: budgets,
          standard_metrics: [],
          dependent_report_datas: [],
          previous_month_report_data: nil,
          previous_year_report_data: nil,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: all_business_chart_of_accounts,
          all_business_vendors: [],
          accounting_classes: accounting_classes,
          qbo_ledgers: {}
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(10.0)
      end
    end
  end
end
