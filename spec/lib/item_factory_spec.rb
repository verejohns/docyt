# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ItemFactory do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'name1') }
  let(:parent_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }

  describe '#create' do
    it 'creates a new item' do
      result = described_class.create(parent_item: parent_item, name: 'name')
      expect(result).to be_success
      expect(result.item).not_to be_nil
    end
  end
end
