# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultiBusinessReportDatasQuery do
  before do
    item_value1
    item_value2
    item_value3
    item_value4
    item_value5
    item_value6
    multi_business_report
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'name1') }
  let(:report_data1) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31') }
  let(:report_data2) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-04-01', end_date: '2021-04-30') }
  let(:report_data3) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_DAILY, start_date: '2021-04-21', end_date: '2021-04-21') }
  let(:item1) { custom_report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
  let(:item2) { custom_report.items.find_or_create_by!(name: 'name2', order: 2, identifier: 'parent_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
  let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, item_identifier: 'parent_item', accumulated_value: 3.0) }
  let(:item_value2) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, item_identifier: 'parent_item1', accumulated_value: 4.0) }
  let(:item_value3) { report_data2.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, item_identifier: 'parent_item', accumulated_value: 6.0) }
  let(:item_value4) { report_data2.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, item_identifier: 'parent_item1', accumulated_value: 8.0) }
  let(:item_value5) { report_data3.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 1.0, item_identifier: 'parent_item') }
  let(:item_value6) { report_data3.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 7.0, item_identifier: 'parent_item1') }
  let(:multi_business_report) do
    MultiBusinessReport.create!(multi_business_report_service_id: 111, template_id: 'owners_operating_statement',
                                name: 'name1', report_ids: [custom_report.id])
  end

  describe '#several_months_report_datas' do
    it 'get aggregated monthly report datas' do
      report_data_query = described_class.new(multi_business_report: multi_business_report, report_datas_params: { from: '2021-03-01'.to_date, to: '2021-04-30'.to_date })
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values[0].value).to eq(6.0)
      expect(report_datas[0].item_values[1].value).to eq(8.0)
      expect(report_datas.count).to eq(2)
    end

    it 'get aggregated daily report datas' do
      report_data_query = described_class.new(multi_business_report: multi_business_report, report_datas_params: { current: '2021-04-21'.to_date, is_daily: true })
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values[0].value).to eq(1.0)
      expect(report_datas[0].item_values[1].value).to eq(7.0)
      expect(report_datas.count).to eq(2)
    end
  end
end
