# frozen_string_literal: true

class SyncReportServicesService
  include DocytLib::Utils::DocytInteractor
  include DocytLib::Async::Publisher

  def sync
    ReportService.where(active: true).each do |report_service|
      publish(events.refresh_reports(report_service_id: report_service.id.to_s))
    end
  end
end
