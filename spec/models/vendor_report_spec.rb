# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VendorReport do
  it { is_expected.to be_mongoid_document }
  it { is_expected.to have_index_for(report_service_id: 1, template_id: 1) }
end
