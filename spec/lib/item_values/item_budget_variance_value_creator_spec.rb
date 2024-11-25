# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemBudgetVarianceValueCreator do
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'report') }
    let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item') }
    let(:child_item) { parent_item.child_items.create!(name: 'child_item', order: 1, identifier: 'child_item') }
    let(:parent_item1) { report.items.create!(name: 'parent_item1', order: 2, identifier: 'parent_item1') }
    let(:child_item1) { parent_item1.child_items.create!(name: 'child_item1', order: 1, identifier: 'child_item1') }
    let(:actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:budget_actual_column) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:budget_variance_column) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: budget_actual_column.range, year: Column::YEAR_CURRENT) }
    let(:ytd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_budget_actual_column) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_budget_variance_column) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: ytd_budget_actual_column.range, year: Column::YEAR_CURRENT) }
    let(:report_data) do
      report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: item_values)
    end
    let(:item_values) do
      [
        {
          item_id: child_item.id.to_s,
          column_id: actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 20.0
        },
        {
          item_id: child_item.id.to_s,
          column_id: budget_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        },
        {
          item_id: child_item.id.to_s,
          column_id: ytd_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 20.0
        },
        {
          item_id: child_item.id.to_s,
          column_id: ytd_budget_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 30.0 }, { budget_id: budget2.id.to_s, value: 30.0 }]
        },
        {
          item_id: parent_item.id.to_s,
          column_id: actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 20.0
        },
        {
          item_id: parent_item.id.to_s,
          column_id: budget_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        }
      ]
    end

    let(:budget1) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget2) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }

    describe '#call' do
      before do
        child_item1
      end

      it 'creates item_value of RANGE_CURRENT for BUDGET_VARIANCE column' do
        item_value = described_class.new(
          report_data: report_data,
          item: child_item,
          column: budget_variance_column,
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
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(10.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value of RANGE_YTD for BUDGET_VARIANCE column' do
        item_value = described_class.new(
          report_data: report_data,
          item: child_item,
          column: ytd_budget_variance_column,
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
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(-10.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value of parent item for BUDGET_VARIANCE column' do
        item_value = described_class.new(
          report_data: report_data,
          item: parent_item,
          column: budget_variance_column,
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
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(10.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end
    end
  end
end
