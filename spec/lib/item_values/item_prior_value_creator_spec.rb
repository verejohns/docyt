# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemPriorValueCreator do
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'report') }
    let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', totals: true) }
    let(:child_item) { parent_item.child_items.create!(name: 'child_item', order: 1, identifier: 'child_item', item_accounts: item_accounts) }
    let(:current_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:current_percentage_column) { report.columns.create!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:current_ly_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR) }
    let(:current_ly_percentage_column) { report.columns.create!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR) }
    let(:ytd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_percentage_column) { report.columns.create!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_ly_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR) }
    let(:ytd_ly_percentage_column) { report.columns.create!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR) }
    let(:current_pp_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD) }
    let(:current_pp_percentage_column) { report.columns.create!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD) }
    let(:report_data) do
      report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28')
    end
    let(:previous_month_report_data) do
      report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-01-01', end_date: '2021-01-31', item_values: item_values)
    end
    let(:previous_year_report_data) do
      report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2020-02-01', end_date: '2020-02-28', item_values: item_values)
    end
    let(:item_values) do
      [
        {
          item_id: child_item.id.to_s,
          column_id: current_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 10.0,
          column_type: 'actual',
          item_account_values: [{ chart_of_account_id: 1001, accounting_class_id: 1, value: 10.0 }]
        },
        {
          item_id: child_item.id.to_s,
          column_id: current_percentage_column.id.to_s,
          item_identifier: 'child_item',
          value: 20.0,
          column_type: 'percentage',
          item_account_values: [{ chart_of_account_id: 1002, accounting_class_id: 2, value: 10.0 }]
        },
        {
          item_id: child_item.id.to_s,
          column_id: ytd_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 30.0,
          column_type: 'actual',
          item_account_values: [{ chart_of_account_id: 1003, accounting_class_id: 1, value: 10.0 }]
        },
        {
          item_id: child_item.id.to_s,
          column_id: ytd_percentage_column.id.to_s,
          item_identifier: 'child_item',
          value: 40.0,
          item_account_values: [
            { chart_of_account_id: 1003, accounting_class_id: 1, value: 10.0 },
            { chart_of_account_id: 1003, accounting_class_id: 2, value: 10.0 }
          ]
        }
      ]
    end
    let(:item_accounts) do
      [
        { chart_of_account_id: 1001, accounting_class_id: 1 },
        { chart_of_account_id: 1002, accounting_class_id: 2 },
        { chart_of_account_id: 1003, accounting_class_id: 1 },
        { chart_of_account_id: 1003, accounting_class_id: 2 }
      ]
    end
    let(:business_chart_of_account1) do
      instance_double(DocytServerClient::BusinessChartOfAccount,
                      id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '60', display_name: 'name1')
    end
    let(:business_chart_of_account2) do
      instance_double(DocytServerClient::BusinessChartOfAccount,
                      id: 2, business_id: 105, chart_of_account_id: 1002, qbo_id: '95', display_name: 'name2')
    end
    let(:business_chart_of_account3) do
      instance_double(DocytServerClient::BusinessChartOfAccount,
                      id: 3, business_id: 105, chart_of_account_id: 1003, qbo_id: '101', display_name: 'name3')
    end
    let(:business_chart_of_accounts) { [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3] }
    let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4') }
    let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1') }
    let(:accounting_classes) { [accounting_class1, accounting_class2] }

    describe '#call' do
      subject(:create_item_value) do
        described_class.new(
          report_data: report_data,
          item: child_item,
          column: current_column,
          budgets: [],
          standard_metrics: [],
          dependent_report_datas: [],
          previous_month_report_data: previous_month_report_data,
          previous_year_report_data: previous_year_report_data,
          january_report_data_of_current_year: nil,
          all_business_chart_of_accounts: business_chart_of_accounts,
          all_business_vendors: [],
          accounting_classes: accounting_classes,
          qbo_ledgers: {}
        ).call
      end

      context 'when current_column is ly actual column' do
        let(:current_column) { current_ly_actual_column }

        it 'copies item_value and item_account_values from ly_report_data for ly actual column' do
          create_item_value
          item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_ly_actual_column.id.to_s)
          expect(item_value.value).to eq(10.0)
          expect(item_value.item_account_values.length).to eq(4)
          expect(item_value.item_account_values[0].value).to eq(10.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        end

        it 'copies item_value and item_account_values from ly_report_data for ly actual column for vendor report' do
          report.update(template_id: Report::VENDOR_REPORT)
          create_item_value
          item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_ly_actual_column.id.to_s)
          expect(item_value.value).to eq(10.0)
          expect(item_value.item_account_values.length).to eq(1)
          expect(item_value.item_account_values[0].value).to eq(10.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        end
      end

      context 'when current_column is ly percentage column' do
        let(:current_column) { current_ly_percentage_column }

        it 'copies item_value and item_account_values from ly_report_data for ly percentage column' do
          create_item_value
          item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_ly_percentage_column.id.to_s)
          expect(item_value.value).to eq(20.0)
          expect(item_value.item_account_values.length).to eq(4)
          expect(item_value.item_account_values[1].value).to eq(10.0)
          expect(item_value.column_type).to eq(Column::TYPE_PERCENTAGE)
        end
      end

      context 'when current_column is ytd ly actual column' do
        let(:current_column) { ytd_ly_actual_column }

        it 'copies item_value and item_account_values from ly_report_data for ytd ly actual column' do
          create_item_value
          item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: ytd_ly_actual_column.id.to_s)
          expect(item_value.value).to eq(30.0)
          expect(item_value.item_account_values.length).to eq(4)
          expect(item_value.item_account_values[2].value).to eq(10.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        end
      end

      context 'when current_column is ytd ly percentage column' do
        let(:current_column) { ytd_ly_percentage_column }

        it 'copies item_value and item_account_values from ly_report_data for ytd ly percentage column' do
          create_item_value
          item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: ytd_ly_percentage_column.id.to_s)
          expect(item_value.value).to eq(40.0)
          expect(item_value.item_account_values.length).to eq(4)
          expect(item_value.item_account_values[2].value).to eq(10.0)
          expect(item_value.item_account_values[3].value).to eq(10.0)
        end
      end

      context 'when current_column is pp actual column' do
        let(:current_column) { current_pp_actual_column }

        it 'copies item_value and item_account_values from pp_report_data for pp actual column' do
          create_item_value
          item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_column.id.to_s)
          expect(item_value.value).to eq(10.0)
          expect(item_value.item_account_values.length).to eq(4)
          expect(item_value.item_account_values[0].value).to eq(10.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        end
      end

      context 'when current_column is pp percentage column' do
        let(:current_column) { current_pp_percentage_column }

        it 'copies item_value and item_account_values from pp_report_data for pp percentage column' do
          create_item_value
          item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_column.id.to_s)
          expect(item_value.value).to eq(20.0)
          expect(item_value.item_account_values.length).to eq(4)
          expect(item_value.item_account_values[1].value).to eq(10.0)
          expect(item_value.column_type).to eq(Column::TYPE_PERCENTAGE)
        end
      end
    end
  end
end
