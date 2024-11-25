# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quickbooks::GeneralLedger, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to belong_to(:report_service) }
    it { is_expected.to embed_many(:line_item_details) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:start_date).of_type(Date) }
    it { is_expected.to have_field(:end_date).of_type(Date) }
  end
end
