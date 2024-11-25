# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemBudgetPercentageValueCreator do
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'report') }
    let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
    let(:child_item1) { parent_item.child_items.create!(name: 'child_item1', order: 1, identifier: 'child_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
    let(:child_item2) { parent_item.child_items.create!(name: 'child_item2', order: 1, identifier: 'child_item2', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
    let(:percentage_item) do
      parent_item.child_items.create!(name: 'percentage_item', order: 2, identifier: 'percentage_item',
                                      values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')))
    end
    let(:source_column) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:percentage_column) { report.columns.create!(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:ytd_source_column) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_percentage_column) { report.columns.create!(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:report_data) do
      report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: item_values)
    end
    let(:item_values) do
      [
        {
          item_id: child_item1.id.to_s,
          column_id: dependent_report_column1.id.to_s,
          item_identifier: 'child_item1',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        },
        {
          item_id: child_item2.id.to_s,
          column_id: source_column.id.to_s,
          item_identifier: 'child_item2',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        },
        {
          item_id: child_item1.id.to_s,
          column_id: dependent_report_column2.id.to_s,
          item_identifier: 'child_item1',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 20.0 }, { budget_id: budget2.id.to_s, value: 20.0 }]
        },
        {
          item_id: child_item2.id.to_s,
          column_id: ytd_source_column.id.to_s,
          item_identifier: 'child_item2',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        }
      ]
    end
    let(:dependent_report) { Report.create!(report_service: report_service, template_id: 'dependent_report', name: 'report') }
    let(:dependent_report_column1) { dependent_report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:dependent_report_column2) { dependent_report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:dependent_report_data) do
      dependent_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: item_values)
    end
    let(:dependent_report_datas) { { 'owners_operating_statement' => dependent_report_data } }

    let(:budget1) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget2) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budgets) { [budget1, budget2] }

    describe '#call' do
      it 'creates item_value of RANGE_CURRENT for BUDGET_PERCENTAGE column' do
        item_value = described_class.new(
          report_data: report_data,
          item: percentage_item,
          column: percentage_column,
          budgets: budgets,
          standard_metrics: [],
          dependent_report_datas: dependent_report_datas,
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
        expect(item_value.budget_values[0][:value]).to eq(100.0)
      end

      it 'creates item_value of RANGE_YTD for BUDGET_PERCENTAGE column' do
        item_value = described_class.new(
          report_data: report_data,
          item: percentage_item,
          column: ytd_percentage_column,
          budgets: budgets,
          standard_metrics: [],
          dependent_report_datas: dependent_report_datas,
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
        expect(item_value.budget_values[0][:value]).to eq(50.0)
      end
    end
  end
end
