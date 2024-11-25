# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDependencies::PreviousDatas, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', name: 'name1') }
  let(:report_data) do
    create(:report_data, report: report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY)
  end
  let(:previous_report_data) do
    create(:report_data, report: report, start_date: '2021-01-01', end_date: '2021-01-31', period_type: ReportData::PERIOD_MONTHLY, updated_at: Time.zone.yesterday)
  end

  describe '#calculate_digest' do
    it 'returns calculated digest' do
      previous_report_data
      report_data.recalc_digest
      expect(described_class.new(report_data)).not_to have_changed
      previous_report_data.update(updated_at: Time.zone.now)
      expect(described_class.new(report_data)).to have_changed
    end
  end
end
