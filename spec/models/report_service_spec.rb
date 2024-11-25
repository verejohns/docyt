# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportService, type: :model do
  it { is_expected.to be_mongoid_document }
  it { is_expected.to have_index_for(service_id: 1) }
  it { is_expected.to have_index_for(business_id: 1) }

  describe 'Associations' do
    it { is_expected.to have_many(:general_ledgers) }
    it { is_expected.to have_many(:budgets) }
    it { is_expected.to have_many(:reports) }
    it { is_expected.to have_one(:report_service_option) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:service_id) }
    it { is_expected.to validate_presence_of(:business_id) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:service_id).of_type(Integer) }
    it { is_expected.to have_field(:business_id).of_type(Integer) }
    it { is_expected.to have_field(:ledgers_imported_at).of_type(DateTime) }
    it { is_expected.to have_field(:updated_at).of_type(DateTime) }
  end
end
