# frozen_string_literal: true

require 'rails_helper'

module AccountValue
  RSpec.describe MultiBusinessReportItemAccountValuesQuery do
    let(:report_service) { ReportService.create!(service_id: 111, business_id: 111) }
    let(:owners_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'name1') }
    let(:report_data) do
      create(:report_data, report: owners_report, start_date: '2021-03-01',
                           end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY)
    end
    let(:parent_item) do
      owners_report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item',
                                  type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, totals: true)
    end
    let(:item1) do
      item = parent_item.child_items.find_or_create_by!(name: 'name1', order: 1, identifier: 'name1')
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 2)
      item
    end
    let(:column) { owners_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:item_value1) { report_data.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 2.0) }
    let(:item_account_value1) { item_value1.item_account_values.create!(chart_of_account_id: 1, accounting_class_id: 1, value: 1.0, name: 'iv_1') }
    let(:item_account_value2) { item_value1.item_account_values.create!(chart_of_account_id: 2, accounting_class_id: 1, value: 2.0, name: 'iv_2') }

    let(:second_report_service) { ReportService.create!(service_id: 112, business_id: 112) }
    let(:second_report) { Report.create!(report_service: second_report_service, template_id: 'owners_operating_statement', name: 'name1') }
    let(:second_report_data) { create(:report_data, report: second_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:second_parent_item) do
      second_report.items.create!(name: 'second_parent_item', order: 2,
                                  identifier: 'second_parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, totals: true)
    end
    let(:second_item1) do
      item = second_parent_item.child_items.find_or_create_by!(name: 'name1', order: 1, identifier: 'name1')
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 3)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 4)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 5)
      item
    end
    let(:second_column) { second_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:second_item_value1) { second_report_data.item_values.create!(item_id: second_item1._id.to_s, column_id: second_column._id.to_s, value: 2.0) }
    let(:second_item_account_value1) { second_item_value1.item_account_values.create!(chart_of_account_id: 3, accounting_class_id: 1, value: 1.0, name: 'iv_1') }
    let(:second_item_account_value2) { second_item_value1.item_account_values.create!(chart_of_account_id: 4, accounting_class_id: 1, value: 2.0, name: 'iv_2') }
    let(:second_item_account_value3) { second_item_value1.item_account_values.create!(chart_of_account_id: 5, accounting_class_id: 1, value: 2.0, name: 'iv_3') }

    let(:multi_business_report) do
      MultiBusinessReport.create!(report_ids: [owners_report.id, second_report.id], multi_business_report_service_id: 111,
                                  template_id: 'owners_operating_statement', name: 'name1')
    end

    describe '#account_values' do
      it 'returns total item_account_values' do
        item_account_value1
        item_account_value2
        second_item_account_value1
        second_item_account_value2
        second_item_account_value3
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name1'
          }

        account_values = described_class.new(multi_business_report: multi_business_report, item_account_values_params: item_account_values_params).item_account_values
        expect(account_values[0].count).to eq(3)
        expect(account_values[1].count).to eq(6)
      end
    end
  end
end
