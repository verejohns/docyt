# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDatasQuery do
  before do
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    item_value1
    item_value2
    item_value3
    item_value4
    item_value5
    item_value6
    item_value7
    item_value8
  end

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) do
    AdvancedReportFactory.create!(report_service: report_service,
                                  report_params: { template_id: 'owners_operating_statement', name: 'name1' }, current_user: user).report
  end
  let(:report_data1) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31') }
  let(:report_data2) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-04-01', end_date: '2021-04-30') }
  let(:item1) { custom_report.find_item_by_identifier(identifier: 'misc_revenue') }
  let(:item2) { custom_report.find_item_by_identifier(identifier: 'other_revenue') }
  let(:rooms_available_item) { custom_report.find_item_by_identifier(identifier: 'rooms_available') }
  let(:rooms_sold_item) { custom_report.find_item_by_identifier(identifier: 'rooms_sold') }
  let(:occupancy_percent_item) { custom_report.find_item_by_identifier(identifier: 'occupancy_percent') }
  let(:rooms_revenue_item) { custom_report.find_item_by_identifier(identifier: 'rooms_revenue') }
  let(:adr_item) { custom_report.find_item_by_identifier(identifier: 'adr') }
  let(:rev_par_item) { custom_report.find_item_by_identifier(identifier: 'rev_par') }
  let(:column) { custom_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, accumulated_value: 3.0) }
  let(:item_value2) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, accumulated_value: 4.0) }
  let(:item_value3) { report_data2.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, accumulated_value: 6.0) }
  let(:item_value4) { report_data2.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, accumulated_value: 8.0) }
  let(:rooms_available_item_value1) { report_data1.item_values.create!(item_id: rooms_available_item._id.to_s, column_id: column._id.to_s, value: 10.0, accumulated_value: 10.0) }
  let(:rooms_sold_item_value1) { report_data1.item_values.create!(item_id: rooms_sold_item._id.to_s, column_id: column._id.to_s, value: 5.0, accumulated_value: 5.0) }
  let(:rooms_revenue_item_value1) { report_data1.item_values.create!(item_id: rooms_revenue_item._id.to_s, column_id: column._id.to_s, value: 3.0, accumulated_value: 3.0) }
  let(:rooms_available_item_value2) { report_data2.item_values.create!(item_id: rooms_available_item._id.to_s, column_id: column._id.to_s, value: 10.0, accumulated_value: 20.0) }
  let(:rooms_sold_item_value2) { report_data2.item_values.create!(item_id: rooms_sold_item._id.to_s, column_id: column._id.to_s, value: 3.0, accumulated_value: 8.0) }
  let(:rooms_revenue_item_value2) { report_data2.item_values.create!(item_id: rooms_revenue_item._id.to_s, column_id: column._id.to_s, value: 3.0, accumulated_value: 6.0) }
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([]) }
  let(:business_api_instance) { instance_double(DocytServerClient::BusinessApi, get_all_business_chart_of_accounts: business_chart_of_accounts_response) }

  let(:store_managers_report) do
    AdvancedReportFactory.create!(report_service: report_service,
                                  report_params: { template_id: 'store_managers_report', name: "Store Manager's Report" }, current_user: user).report
  end
  let(:report_data3) { store_managers_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-04-01', end_date: '2021-04-30') }
  let(:item3) { store_managers_report.find_item_by_identifier(identifier: 'retail_shipping_supplies') }
  let(:item4) { store_managers_report.find_item_by_identifier(identifier: 'packaging_materials') }
  let(:actual_column) { store_managers_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:gross_actual_column) { store_managers_report.columns.find_by(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value5) { report_data3.item_values.create!(item_id: item3._id.to_s, column_id: actual_column._id.to_s, value: 35.0, accumulated_value: 70.0) }
  let(:item_value6) { report_data3.item_values.create!(item_id: item3._id.to_s, column_id: gross_actual_column._id.to_s, value: 30.0, accumulated_value: 60.0) }
  let(:item_value7) { report_data3.item_values.create!(item_id: item4._id.to_s, column_id: actual_column._id.to_s, value: 45.0, accumulated_value: 90.0) }
  let(:item_value8) { report_data3.item_values.create!(item_id: item4._id.to_s, column_id: gross_actual_column._id.to_s, value: 40.0, accumulated_value: 80.0) }

  let(:report_data4) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_DAILY, start_date: '2021-03-05', end_date: '2021-03-05') }
  let(:item_value9) { report_data4.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.5, accumulated_value: 6.0) }
  let(:item_value10) { report_data4.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.5, accumulated_value: 8.0) }

  describe '#several_months_report_datas' do
    let(:report_datas_params) do
      {
        from: '2021-03-01',
        to: '2021-04-30'
      }
    end

    it 'get report datas with total values' do
      report_data_query = described_class.new(report: custom_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item1._id.to_s).value).to eq(6.0)
      expect(report_datas[0].item_values.find_by(item_id: item2._id.to_s).value).to eq(8.0)
      expect(report_datas.count).to eq(3)
    end

    it 'get report datas with Total Occupancy % value' do
      rooms_available_item_value1
      rooms_sold_item_value1
      rooms_available_item_value2
      rooms_sold_item_value2
      report_data_query = described_class.new(report: custom_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: occupancy_percent_item._id.to_s).value).to eq(40.0)
    end

    it 'get report datas with Total ADR and Total RevPar value' do
      rooms_available_item_value1
      rooms_sold_item_value1
      rooms_revenue_item_value1
      rooms_available_item_value2
      rooms_sold_item_value2
      rooms_revenue_item_value2
      report_data_query = described_class.new(report: custom_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: adr_item._id.to_s).value).to eq(0.75)
      expect(report_datas[0].item_values.find_by(item_id: rev_par_item._id.to_s).value).to eq(0.3)
    end

    it 'get report datas without total values' do
      report_datas_params =
        {
          from: '2021-03-01',
          to: '2021-04-30'
        }

      report_data_query = described_class.new(report: custom_report, report_datas_params: report_datas_params, include_total: false)
      report_datas = report_data_query.report_datas
      expect(report_datas.count).to eq(2)
    end

    it 'get report datas with total values for store_managers_report' do
      report_data_query = described_class.new(report: store_managers_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item3._id.to_s, column_id: actual_column._id.to_s).value).to eq(35.0)
      expect(report_datas[0].item_values.find_by(item_id: item3._id.to_s, column_id: gross_actual_column._id.to_s).value).to eq(30.0)
      expect(report_datas[0].item_values.find_by(item_id: item4._id.to_s, column_id: actual_column._id.to_s).value).to eq(45.0)
      expect(report_datas[0].item_values.find_by(item_id: item4._id.to_s, column_id: gross_actual_column._id.to_s).value).to eq(40.0)
    end
  end

  describe 'For daily reports' do
    let(:report_datas_params) do
      {
        current: '2021-03-05',
        is_daily: true
      }
    end

    it 'get report data' do
      item_value9
      item_value10
      report_data_query = described_class.new(report: custom_report, report_datas_params: report_datas_params, include_total: false)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item1._id.to_s).value).to eq(3.5)
      expect(report_datas[0].item_values.find_by(item_id: item2._id.to_s).value).to eq(4.5)
      expect(report_datas.count).to eq(1)
    end
  end
end
