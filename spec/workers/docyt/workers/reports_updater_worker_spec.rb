# frozen_string_literal: true

require 'rails_helper'
module Docyt
  module Workers
    RSpec.describe ReportsUpdaterWorker do
      before do
        allow(ReportFactory).to receive(:new).and_return(report_factory)
        allow(Quickbooks::UnincludedLineItemDetailsFactory).to receive(:new).and_return(unincluded_line_item_details_factory)
      end

      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }

      let(:owner_report) do
        create(:advanced_report, name: 'Owners Report', report_service: report_service,
                                 template_id: 'owners_operating_statement', missing_transactions_calculation_disabled: false)
      end
      let(:report) do
        create(:advanced_report, name: 'Test Report', report_service: report_service, template_id: 'test_template',
                                 dependent_template_ids: ['owners_operating_statement'], missing_transactions_calculation_disabled: false)
      end

      let(:department_report) { AdvancedReport.create!(report_service: report_service, template_id: Report::DEPARTMENT_REPORT, name: 'Department report') }
      let(:pl_report) do
        ProfitAndLossReport.create!(report_service: report_service, template_id: ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID,
                                    name: 'name1')
      end
      let(:balance_sheet_report) { BalanceSheetReport.create!(report_service: report_service, template_id: BalanceSheetReport::BALANCE_SHEET_REPORT, name: 'Balance Sheet') }

      let(:report_factory) { instance_double(ReportFactory, refill_report: true) }
      let(:unincluded_line_item_details_factory) { instance_double(Quickbooks::UnincludedLineItemDetailsFactory, create_for_report: true) }

      describe '.perform' do
        subject(:perform) { described_class.new.perform(event) }

        context 'when update advanced_reports' do
          let(:event) do
            DocytLib.async.events.refresh_report_request(
              report_id: owner_report.id.to_s
            ).body
          end

          it 'updates reports in report service' do
            report
            perform
            expect(DocytLib.async.event_queue.events.last.priority).to eq(5)
            expect(report_factory).to have_received(:refill_report).once
          end

          it 'updates reports in report service with manual queued' do
            Thread.current[:message_priority] = ReportFactory::MANUAL_UPDATE_PRIORITY
            owner_report.update(update_state: Report::UPDATE_STATE_QUEUED)
            report
            perform
            expect(DocytLib.async.event_queue.events.last.priority).to eq(ReportFactory::MANUAL_UPDATE_PRIORITY)
            expect(report_factory).to have_received(:refill_report).once
          ensure
            Thread.current[:message_priority] = nil
          end

          it 'creates unincluded_line_item_details' do
            perform
            expect(unincluded_line_item_details_factory).to have_received(:create_for_report)
          end
        end

        context 'when update department report' do
          let(:event) do
            DocytLib.async.events.refresh_report_request(
              report_id: department_report.id.to_s
            ).body
          end

          it 'updates report' do
            perform
            expect(report_factory).to have_received(:refill_report).exactly(1).times
          end
        end

        context 'when update profit and loss report' do
          let(:event) do
            DocytLib.async.events.refresh_report_request(
              report_id: pl_report.id.to_s
            ).body
          end

          it 'updates report' do
            perform
            expect(report_factory).to have_received(:refill_report).exactly(1).times
          end
        end

        context 'when update balance_sheet_report' do
          let(:event) do
            DocytLib.async.events.refresh_report_request(
              report_id: balance_sheet_report.id.to_s
            ).body
          end

          it 'updates report' do
            perform
            expect(report_factory).to have_received(:refill_report).exactly(1).times
          end
        end
      end
    end
  end
end
