# frozen_string_literal: true

require 'rails_helper'
module Docyt
  module Workers
    RSpec.describe ReportDataUpdaterWorker do
      subject(:perform) { described_class.new.perform(event) }

      before do
        allow(ReportDataUpdater).to receive(:new).and_return(updater_factory)
      end

      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }

      let(:owner_report) { create(:report, name: 'Owners Report', report_service: report_service, template_id: 'owners_operating_statement') }

      let(:report_data) { owner_report.report_datas.create!(period_type: ReportData::PERIOD_DAILY, start_date: '2021-03-05', end_date: '2021-03-05') }

      let(:updater_factory) { instance_double(ReportDataUpdater, update_report_data: true) }

      describe '#perform' do
        let(:event) do
          DocytLib.async.events.refresh_report_data(
            report_data_id: report_data.id.to_s
          ).body
        end

        it 'updates a report' do
          perform
          expect(updater_factory).to have_received(:update_report_data)
        end
      end
    end
  end
end
