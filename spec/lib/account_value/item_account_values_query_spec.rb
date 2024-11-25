# frozen_string_literal: true

require 'rails_helper'

module AccountValue
  RSpec.describe ItemAccountValuesQuery do
    let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
    let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'name1') }
    let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:daily_report_data) { create(:report_data, report: custom_report, start_date: '2021-03-31', end_date: '2021-03-31', period_type: ReportData::PERIOD_DAILY) }
    let(:parent_item) do
      custom_report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item',
                                  type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, totals: true)
    end
    let(:item1) do
      item = parent_item.child_items.find_or_create_by!(name: 'name1', order: 1, identifier: 'name1')
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 2)
      item
    end
    let(:item2) do
      item = parent_item.child_items.find_or_create_by!(name: 'name2', order: 1, identifier: 'name2')
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 3)
      item
    end
    let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:item_value1) { report_data.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 2.0) }
    let(:item_value2) { report_data.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 3.0) }
    let(:item_account_value1) { item_value1.item_account_values.create!(chart_of_account_id: 1, accounting_class_id: 1, value: 1.0) }
    let(:item_account_value2) { item_value1.item_account_values.create!(chart_of_account_id: 2, accounting_class_id: 1, value: 2.0) }
    let(:item_account_value3) { item_value2.item_account_values.create!(chart_of_account_id: 3, accounting_class_id: 1, value: 3.0) }

    let(:daily_item_value1) { daily_report_data.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 2.0) }
    let(:daily_item_value2) { daily_report_data.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 3.0) }
    let(:daily_item_account_value1) { item_value1.item_account_values.create!(chart_of_account_id: 1, accounting_class_id: 1, value: 1.0) }
    let(:daily_item_account_value2) { item_value1.item_account_values.create!(chart_of_account_id: 2, accounting_class_id: 1, value: 2.0) }
    let(:daily_item_account_value3) { item_value2.item_account_values.create!(chart_of_account_id: 3, accounting_class_id: 1, value: 3.0) }

    describe '#account_values' do
      it 'returns total item_account_values' do
        item_account_value1
        item_account_value2
        item_account_value3
        daily_item_account_value1
        daily_item_account_value2
        daily_item_account_value3
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name1'
          }

        account_values = described_class.new(report: custom_report, item_account_values_params: item_account_values_params).item_account_values
        expect(account_values.count).to eq(2)
      end

      it 'returns total item_account_values for vendor report' do
        custom_report.update(template_id: Report::VENDOR_REPORT)
        item_account_value1
        item_account_value2
        item_account_value3
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name1'
          }

        account_values = described_class.new(report: custom_report, item_account_values_params: item_account_values_params).item_account_values
        expect(account_values.count).to eq(2)
      end
    end
  end
end
