# frozen_string_literal: true

require 'csv'
namespace :report_services do # rubocop:disable Metrics/BlockLength
  desc 'Sync all report_services'
  task sync_all: :environment do |_t, _args|
    SyncReportServicesService.sync
  end

  desc 'Re-update all report datas'
  task force_update_all_report_datas: :environment do |_t, _args|
    ReportData.update_all(dependency_digests: {}) # rubocop:disable Rails/SkipsModelValidations
    SyncReportServicesService.sync
  end

  desc 'Create Balance Sheet report for all report services'
  task create_balance_sheet_reports: :environment do |_t, _args|
    ReportService.where(active: true).each do |report_service|
      next if BalanceSheetReport.where(report_service: report_service).present?

      result = BalanceSheetReportFactory.create(report_service: report_service)
      result.report.refresh_all_report_datas
      puts "Balance Sheet Report was created for this business: #{report_service.business_id}"
    rescue DocytServerClient::ApiError => e
      DocytLib.logger.debug(e.message)
      next
    end
  end

  desc 'Exports all report types as CSV'
  task export_all_report_types_as_csv: :environment do |_t, _args|
    all_templates = TemplatesQuery.new.all_templates
    title_row = ['Business Id'] + all_templates.pluck(:name)
    CSV.open('all_report_types_per_business.csv', 'wb') do |csv|
      csv << title_row
      ReportService.each do |report_service|
        business_info = [report_service.business_id]
        all_templates.each do |template|
          business_info << if report_service.reports.pluck(:template_id).include?(template[:id])
                             'Yes'
                           else
                             'No'
                           end
        end
        csv << business_info
      end
    end
  end
end
