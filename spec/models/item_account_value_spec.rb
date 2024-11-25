# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ItemAccountValue, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to be_embedded_in(:item_value) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:chart_of_account_id) }
    it { is_expected.to validate_presence_of(:value) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:chart_of_account_id).of_type(Integer) }
    it { is_expected.to have_field(:accounting_class_id).of_type(Integer) }
    it { is_expected.to have_field(:name).of_type(String) }
    it { is_expected.to have_field(:value).of_type(Float) }
  end

  describe '#line_item_details' do
    before do
      allow(Quickbooks::LineItemDetailsQuery).to receive(:new).and_return(line_item_details_query)
    end

    let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
    let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'name1') }
    let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:item) { custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
    let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:item_value) { report_data.item_values.create!(item_id: item._id.to_s, column_id: column._id.to_s, value: 3.0) }
    let(:line_item_detail) { Quickbooks::LineItemDetail.new(amount: 10.0) }
    let(:line_item_details_query) { instance_double(Quickbooks::LineItemDetailsQuery, by_period: [line_item_detail]) }
    let(:item_account_value) { described_class.new(chart_of_account_id: 333, accounting_class_id: 10, value: 10.0, name: 'test item value', item_value: item_value) }

    it 'returns array of line_item_detail' do
      line_item_details = item_account_value.line_item_details
      expect(line_item_details.length).to eq(1)
      expect(line_item_details[0].amount).to eq(10.0)
    end

    it 'calls Quickbooks::LineItemDetailsQuery to fetch line items' do
      item_account_value.line_item_details
      expect(line_item_details_query).to have_received(:by_period)
    end
  end
end
