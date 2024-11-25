# frozen_string_literal: true

# == Mongoid Information
#
# Document name: item_values
#
#  id                   :string
#  value                :string
#  item_id              :ObjectId
#  column_id            :ObjectId
#  value                :Float
#  item_identifier      :string
#

require 'rails_helper'

RSpec.describe ItemValueSerializer do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'name1') }
  let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31') }
  let(:item1) { report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'parent_item') }
  let(:column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value1) { report_data.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, budget_values: []) }

  it 'contains item_value information in json' do
    json_string = described_class.new(item_value1).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['item_value']['id']).not_to be_nil
    expect(result_hash['item_value']['item_id']).to eq(item1._id.to_s)
    expect(result_hash['item_value']['column_id']).to eq(column._id.to_s)
    expect(result_hash['item_value']['value']).to eq(3.0)
  end
end
