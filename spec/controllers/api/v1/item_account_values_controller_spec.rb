# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ItemAccountValuesController do
  before do
    allow_any_instance_of(described_class).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow(Quickbooks::LineItemDetailsQuery).to receive(:new).and_return(line_item_details_query)
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'name1') }
  let(:from) { '2021-01-01' }
  let(:to) { '2021-02-28' }
  let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
  let(:item) { custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
  let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value) { report_data.item_values.create!(item_id: item._id.to_s, column_id: column._id.to_s, value: 3.0) }
  let(:item_account_value) { item_value.item_account_values.create!(chart_of_account_id: 1, accounting_class_id: 2, name: 'name', value: 3.0) }
  let(:line_item_detail) { Quickbooks::LineItemDetail.new(amount: 10.0) }
  let(:line_item_details_query) { instance_double(Quickbooks::LineItemDetailsQuery, by_period: [line_item_detail]) }

  describe 'GET #show' do
    subject(:show_response) do
      get :show, params: params
    end

    context 'with valid params' do
      let(:params) do
        {
          report_id: custom_report._id,
          item_value_id: item_value._id,
          id: item_account_value._id
        }
      end

      it 'returns 200 response when the user has permission' do
        show_response
        expect(response).to have_http_status(:ok)
      end

      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        show_response
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          report_id: custom_report._id,
          item_value_id: Faker::Number.number(digits: 10),
          id: item_account_value._id
        }
      end

      it 'returns 422 response' do
        show_response
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #line_item_detail' do
    subject(:line_item_details_response) do
      get :line_item_details, params: params
    end

    context 'with valid params' do
      let(:params) do
        {
          report_id: custom_report._id,
          item_value_id: item_value._id,
          id: item_account_value._id
        }
      end

      it 'returns line_item_detail array when the user has permission' do
        line_item_details_response
        expect(response).to have_http_status(:ok)
      end

      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        line_item_details_response
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          report_id: custom_report._id,
          item_value_id: Faker::Number.number(digits: 10),
          id: item_account_value._id
        }
      end

      it 'returns 422 response' do
        line_item_details_response
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
