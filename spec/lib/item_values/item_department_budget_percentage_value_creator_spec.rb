# frozen_string_literal: true

require 'rails_helper'

module ItemValues
  RSpec.describe ItemDepartmentBudgetPercentageValueCreator do
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
    let(:revenue_total_item) do
      revenue_parent_item.child_items.create!(name: 'total_revenue', order: 1, identifier: 'total_revenue', totals: true)
    end

    let(:item_values) do
      [
        {
          item_id: revenue_total_item.id.to_s,
          column_id: department_budget_actual_column.id.to_s,
          item_identifier: 'total_revenue',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 100.0 }, { budget_id: budget2.id.to_s, value: 200.0 }]
        },
        {
          item_id: revenue_child_item.id.to_s,
          column_id: department_budget_actual_column.id.to_s,
          item_identifier: 'revenue_1',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 20.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        }
      ]
    end
    let(:department_budget_actual_column) { department_report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:department_budget_percentage_column) { department_report.columns.create!(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:department_report_data) do
      department_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: item_values)
    end

    let(:budget1) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget2) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }

    describe '#call' do
      it 'creates budget_values for percentage column' do
        item_value = described_class.new(
          report_data: department_report_data,
          item: revenue_child_item,
          column: department_budget_percentage_column,
          budgets: [],
          standard_metrics: [],
          dependent_report_datas: [],
          previous_month_report_data: nil,
          previous_year_report_data: nil,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: [],
          all_business_vendors: [],
          accounting_classes: [],
          qbo_ledgers: {}
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_PERCENTAGE)
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(20.0)
        expect(item_value.budget_values[1][:value]).to eq(5.0)
      end
    end
  end
end
