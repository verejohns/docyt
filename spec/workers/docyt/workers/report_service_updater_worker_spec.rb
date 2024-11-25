# frozen_string_literal: true

require 'rails_helper'
module Docyt
  module Workers
    RSpec.describe ReportServiceUpdaterWorker do
      before do
        allow(ReportsInReportServiceUpdater).to receive(:new).and_return(updater_factory)
      end

      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }

      let(:owner_report) { create(:report, name: 'Owners Report', report_service: report_service, template_id: 'owners_operating_statement') }

      let(:updater_factory) { instance_double(ReportsInReportServiceUpdater, update_all_reports: true, update_report: true) }

      describe '.perform' do
        subject(:perform) { described_class.new.perform(event) }

        context 'when update report service' do
          let(:event) do
            DocytLib.async.events.refresh_reports(
              report_service_id: report_service.id.to_s
            ).body
          end

          it 'updates reports in report service' do
            perform
            expect(updater_factory).to have_received(:update_all_reports)
          end
        end

        context 'when update a report' do
          let(:event) do
            DocytLib.async.events.refresh_reports(
              report_service_id: report_service.id.to_s,
              report_id: owner_report.id.to_s
            ).body
          end

          it 'updates a report' do
            perform
            expect(updater_factory).to have_received(:update_report)
          end
        end
      end
    end
  end
end
