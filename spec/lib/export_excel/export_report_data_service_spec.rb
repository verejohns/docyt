# frozen_string_literal: true

require 'rails_helper'

module ExportExcel
  RSpec.describe ExportReportDataService do
    before do
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(Axlsx::Worksheet).to receive(:new).and_return(work_sheet_instance)
      item_value1
      item_value2
      item_value3
      item_value4
      item_value9
      item_account_value1
      item_account_value2
    end

    let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
    let(:custom_report) { AdvancedReport.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'name1', view_by_options: ['rooms_sold']) }
    let(:report_data1) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:report_data2) { create(:report_data, report: custom_report, start_date: '2021-04-01', end_date: '2021-04-30', period_type: ReportData::PERIOD_MONTHLY) }
    let(:last_reconciled_month_data) { Struct.new(:year, :month, :status).new(2021, 1, 'reconciled') }
    let(:business_response) do
      instance_double(DocytServerClient::BusinessDetail, id: 1, bookkeeping_start_date: (Time.zone.today - 1.month),
                                                         display_name: 'My Business', name: 'My Business', last_reconciled_month_data: last_reconciled_month_data)
    end
    let(:business_info) { Struct.new(:business).new(business_response) }
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
    let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
    let(:business_api_instance) do
      instance_double(DocytServerClient::BusinessApi, get_business: business_info,
                                                      get_business_chart_of_accounts: business_chart_of_accounts_response)
    end
    let(:sheet_row) { Struct.new(:outline_level, :hidden).new(0, false) }
    let(:sheet_view) { Struct.new(:view).new({ show_outline_symbols: false }) }
    let(:work_sheet_instance) { instance_double(Axlsx::Worksheet, add_row: sheet_row, sheet_view: sheet_view) }
    let(:item1) do
      custom_report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'parent_item')
    end
    let(:item2) do
      item1.child_items.find_or_create_by!(name: 'name2', order: 2, identifier: 'child_item_1',
                                           type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
    end
    let(:item_account1) do
      item2.item_accounts.find_or_create_by!(chart_of_account_id: 1001)
    end
    let(:item_account2) do
      item2.item_accounts.find_or_create_by!(chart_of_account_id: 1002)
    end
    let(:item3) do
      item1.child_items.find_or_create_by!(name: 'name3', order: 3, identifier: 'child_item_2',
                                           type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
    end
    let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT, name: 'PTD $') }
    let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, column_type: Column::TYPE_ACTUAL) }
    let(:item_value2) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, column_type: Column::TYPE_ACTUAL) }
    let(:item_value3) { report_data2.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, column_type: Column::TYPE_PERCENTAGE) }
    let(:item_value4) { report_data2.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, column_type: Column::TYPE_ACTUAL) }
    let(:item_value9) { report_data1.item_values.create!(item_id: item3._id.to_s, column_id: column._id.to_s, value: 4.0, column_type: Column::TYPE_VARIANCE) }

    let(:item_account_value1) { item_value2.item_account_values.find_or_create_by!(chart_of_account_id: item_account1.chart_of_account_id, name: 'test1', value: 2) }
    let(:item_account_value2) { item_value2.item_account_values.find_or_create_by!(chart_of_account_id: item_account2.chart_of_account_id, name: 'test2', value: 2) }

    describe '#call' do
      it 'creates a new report with items and columns' do
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date)
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(32)
      end
    end

    describe '#call_with_period' do
      it 'creates a new report with multiple months' do
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-04-30'.to_date)
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(54)
      end
    end
  end
end
