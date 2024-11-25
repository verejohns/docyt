# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncReportServicesService, service: true do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }

  describe '#sync' do
    subject(:sync_report_services) { described_class.sync }

    let(:report_service) { create(:report_service) }

    it 'publishes refresh_reports event to update report_datas' do
      report_service
      expect do
        sync_report_services
      end.to change { DocytLib.async.event_queue.size }.by(1)
    end
  end
end
