# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemBudgetActualsValueCreator do
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'report') }
    let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
    let(:child_item1) do
      item = parent_item.child_items.create!(name: 'child_item1', order: 1, identifier: 'child_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1001)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1002)
      item
    end
    let(:child_item2) do
      item = parent_item.child_items.create!(name: 'child_item2', order: 1, identifier: 'child_item2', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, negative: true)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1001)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1002)
      item
    end
    let(:metric_item1) do
      report.items.create!(name: 'Rooms Available to sell', order: 3, identifier: 'rooms_available',
                           type_config: { 'name' => Item::TYPE_METRIC, 'metric' => { 'name' => 'Available Rooms' } })
    end
    let(:metric_item2) do
      report.items.create!(name: 'Rooms Sold', order: 3, identifier: 'rooms_sold', type_config: { 'name' => Item::TYPE_METRIC, 'metric' => { 'name' => 'Sold Rooms' } })
    end
    let(:reference_item1) do
      parent_item.child_items.create!(name: 'Rooms Available to sell', order: 4, identifier: 'reference_item1',
                                      type_config: { 'name' => Item::TYPE_REFERENCE, 'metric' => { 'name' => 'Available Rooms' } })
    end
    let(:reference_item2) do
      parent_item.child_items.create!(name: 'Rooms Sold', order: 4, identifier: 'reference_item2',
                                      type_config: { 'name' => Item::TYPE_REFERENCE, 'metric' => { 'name' => 'Sold Rooms' } })
    end
    let(:stats_plus_item) do
      parent_item.child_items.create!(name: 'stats_plus_item', order: 2, identifier: 'stats_plus_item', type_config: { 'name' => Item::TYPE_STATS },
                                      values_config: JSON.parse(File.read('./spec/data/values_config/stats_plus_item.json')))
    end
    let(:stats_minus_item) do
      parent_item.child_items.create!(name: 'stats_minus_item', order: 2, identifier: 'stats_minus_item', type_config: { 'name' => Item::TYPE_STATS },
                                      values_config: JSON.parse(File.read('./spec/data/values_config/stats_minus_item.json')))
    end
    let(:stats_sum_item) do
      parent_item.child_items.create!(name: 'stats_sum_item', order: 2, identifier: 'stats_sum_item', type_config: { 'name' => Item::TYPE_STATS },
                                      values_config: JSON.parse(File.read('./spec/data/values_config/stats_sum_item.json')))
    end
    let(:stats_percentage_item) do
      parent_item.child_items.create!(name: 'stats_percentage_item', order: 2, identifier: 'stats_percentage_item', type_config: { 'name' => Item::TYPE_STATS },
                                      values_config: JSON.parse(File.read('./spec/data/values_config/stats_percentage_item.json')))
    end

    let(:column1) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:ytd_column1) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28') }

    let(:admin_parent_item) { report.items.create!(name: 'admin_parent_item', order: 2, identifier: 'admin_parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
    let(:admin_total_item) { admin_parent_item.child_items.create!(name: 'total_admin_item', order: 2, identifier: 'total_admin_item', totals: true) }
    let(:admin_child_item1) do
      admin_parent_item.child_items.create!(name: 'admin_child_item1', order: 1, identifier: 'admin_child_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
    end
    let(:admin_child_item2) do
      admin_parent_item.child_items.create!(name: 'admin_child_item2', order: 1, identifier: 'admin_child_item2', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
    end
    let(:item_values) do
      [
        {
          item_id: admin_child_item1.id.to_s,
          column_id: column1.id.to_s,
          item_identifier: 'admin_child_item1',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        },
        {
          item_id: admin_child_item1.id.to_s,
          column_id: ytd_column1.id.to_s,
          item_identifier: 'admin_child_item1',
          value: 5.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        },
        {
          item_id: admin_child_item2.id.to_s,
          column_id: column1.id.to_s,
          item_identifier: 'admin_child_item2',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        }
      ]
    end
    let(:report_data_with_item_values) do
      report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: item_values)
    end

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
    let(:standard_metric1) { StandardMetric.create!(name: 'Rooms Available to sell', type: 'Available Rooms', code: 'rooms_available') }
    let(:standard_metric2) { StandardMetric.create!(name: 'Rooms Sold', type: 'Sold Rooms', code: 'rooms_sold') }
    let(:standard_metrics) { [standard_metric1, standard_metric2] }
    let(:budget1) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget2) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:actual_budget_items) do
      ActualBudgetItem.create!(budget_id: budget1.id, standard_metric_id: standard_metric1.id.to_s, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget1.id, standard_metric_id: standard_metric2.id.to_s, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 1001, accounting_class_id: 1, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 1002, accounting_class_id: 1, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, standard_metric_id: standard_metric1.id.to_s, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, standard_metric_id: standard_metric2.id.to_s, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 1001, accounting_class_id: 1, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 1002, accounting_class_id: 1, budget_item_values: budget_item_values)
    end
    let(:budgets) { [budget1, budget2] }

    describe '#call' do
      before do
        child_item1
        child_item2
        actual_budget_items
      end

      it 'creates item_value for RANGE_CURRENT column' do
        item_value = described_class.new(
          report_data: report_data,
          item: child_item1,
          column: column1,
          budgets: budgets,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          previous_month_report_data: nil,
          previous_year_report_data: nil,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: [],
          all_business_vendors: [],
          accounting_classes: [],
          qbo_ledgers: {}
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(20.0)
      end

      it 'creates item_value for metric item' do
        item_value = described_class.new(
          report_data: report_data,
          item: metric_item1,
          column: column1,
          budgets: budgets,
          standard_metrics: standard_metrics,
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
        expect(item_value.column_type).to eq(Column::TYPE_VARIANCE)
      end

      it 'creates item_value for reference item' do
        item_value = described_class.new(
          report_data: report_data,
          item: reference_item1,
          column: column1,
          budgets: budgets,
          standard_metrics: standard_metrics,
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
        expect(item_value.column_type).to eq(Column::TYPE_VARIANCE)
      end

      it 'creates item_value for stats(plus) item' do
        item_value = described_class.new(
          report_data: report_data,
          item: stats_plus_item,
          column: column1,
          budgets: budgets,
          standard_metrics: standard_metrics,
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
        expect(item_value.budget_values[0][:value]).to eq(40.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value for stats(minus) item' do
        item_value = described_class.new(
          report_data: report_data,
          item: stats_minus_item,
          column: column1,
          budgets: budgets,
          standard_metrics: standard_metrics,
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
        expect(item_value.budget_values[0][:value]).to eq(0.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value for stats(sum) item' do
        item_value = described_class.new(
          report_data: report_data,
          item: stats_sum_item,
          column: column1,
          budgets: budgets,
          standard_metrics: standard_metrics,
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
        expect(item_value.budget_values[0][:value]).to eq(0.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value for stats(percentage) item' do
        item_value = described_class.new(
          report_data: report_data,
          item: stats_percentage_item,
          column: column1,
          budgets: budgets,
          standard_metrics: standard_metrics,
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
        expect(item_value.budget_values[0][:value]).to eq(100.0)
        expect(item_value.column_type).to eq(Column::TYPE_PERCENTAGE)
      end

      it 'creates item_value(total) for parent item' do
        item_value = described_class.new(
          report_data: report_data_with_item_values,
          item: admin_total_item,
          column: column1,
          budgets: budgets,
          standard_metrics: standard_metrics,
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
        expect(item_value.budget_values[0][:value]).to eq(20.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value for ytd column' do # rubocop:disable RSpec/ExampleLength
        report_data.item_values.new(
          item_id: admin_child_item1.id.to_s, column_id: column1.id.to_s, value: 0.0,
          budget_values: [
            { budget_id: budget1.id.to_s, value: 5.0 },
            { budget_id: budget2.id.to_s, value: 10.0 }
          ]
        )
        item_value = described_class.new(
          report_data: report_data,
          item: admin_child_item1,
          column: ytd_column1,
          budgets: budgets,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          previous_month_report_data: report_data_with_item_values,
          previous_year_report_data: nil,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: [],
          all_business_vendors: [],
          accounting_classes: [],
          qbo_ledgers: {}
        ).call
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(15.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end
    end
  end
end
