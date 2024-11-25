# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDependencies::Quickbooks, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'vendor_report', name: 'name1') }
  let(:report_data) do
    create(:report_data, report: report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY)
  end
  let(:general_ledger) { Quickbooks::VendorGeneralLedger.create!(report_service: report_service, start_date: '2021-03-01', end_date: '2021-03-31') }
  let(:line_item_detail) { general_ledger.line_item_details.create(transaction_date: '2021-03-02', amount: 10) }

  describe '#calculate_digest' do
    it 'returns calculated digest' do
      line_item_detail
      report_data.recalc_digest
      expect(described_class.new(report_data)).not_to have_changed
      line_item_detail.update(amount: 5)
      expect(described_class.new(report_data)).to have_changed
    end
  end

  describe '#refresh' do
    before do
      allow(::Quickbooks::GeneralLedgerImporter).to receive(:new).and_return(importer_instance)
      allow(::Quickbooks::GeneralLedgerAnalyzer).to receive(:analyze).and_return(true)
    end

    let(:importer_instance) { instance_double(Quickbooks::GeneralLedgerImporter, fetch_qbo_token: true, import: true) }

    it 'works nothing' do
      described_class.new(report_data).refresh
      expect(importer_instance).not_to have_received(:fetch_qbo_token)
    end

    it 'imports general ledgers' do
      report_data.update(period_type: ReportData::PERIOD_DAILY, end_date: report_data.start_date)
      described_class.new(report_data).refresh
      expect(importer_instance).to have_received(:fetch_qbo_token)
    end
  end
end
