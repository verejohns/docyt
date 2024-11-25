# frozen_string_literal: true

module ExportExcel
  class ReportExportService
    include DocytLib::Utils::DocytInteractor

    DATA_EXPORT_TYPE = 'business_report'
    DATA_EXPORT_READY_STATE = 'ready'
    DATA_EXPORT_ERROR_STATE = 'error'

    def call(export_report:) # rubocop:disable Metrics/MethodLength
      create_data_export(export_report: export_report)
      report_result = case export_report.export_type
                      when ExportReport::EXPORT_TYPE_REPORT
                        export_report_as_excel(export_report: export_report)
                      when ExportReport::EXPORT_TYPE_MULTI_ENTITY_REPORT
                        export_multi_entity_report(export_report: export_report)
                      else
                        export_consolidated_report(export_report: export_report)
                      end
      unless report_result.success?
        DocytLib.logger.error(report_result.errors)
        update_data_export(state: DATA_EXPORT_ERROR_STATE)
        return
      end
      exported_file_token = upload_file(filename: File.basename(report_result.report_file_path), source_file: File.read(report_result.report_file_path))
      return if exported_file_token.blank?

      update_data_export(exported_file_token: exported_file_token)
    end

    private

    def create_data_export(export_report:) # rubocop:disable Metrics/MethodLength
      data_export_api_instance = DocytServerClient::DataExportApi.new
      name_and_business_ids = generate_name_and_business_ids(export_report: export_report)
      response = data_export_api_instance.create_data_export({ business_ids: name_and_business_ids[:business_ids],
                                                               user_id: export_report.user_id,
                                                               data_export: {
                                                                 name: name_and_business_ids[:name],
                                                                 export_type: DATA_EXPORT_TYPE,
                                                                 start_date: export_report.start_date,
                                                                 end_date: export_report.end_date
                                                               } })
      @data_export = response.data_export
    end

    def export_report_as_excel(export_report:)
      report = Report.find(export_report.report_id)
      if report.departmental_report?
        ExportExcel::ExportDepartmentReportDataService.call(report: report,
                                                            start_date: export_report.start_date, end_date: export_report.end_date,
                                                            filter: export_report.filter)
      elsif export_report.start_date == export_report.end_date
        ExportExcel::ExportDailyReportDataService.call(report: report, current_date: export_report.start_date)
      else
        ExportExcel::ExportReportDataService.call(report: report, start_date: export_report.start_date, end_date: export_report.end_date)
      end
    end

    def export_multi_entity_report(export_report:)
      multi_business_report = MultiBusinessReport.find(export_report.multi_business_report_id)
      ExportExcel::ExportMultiBusinessReportDataService.call(multi_business_report: multi_business_report,
                                                             start_date: export_report.start_date, end_date: export_report.end_date)
    end

    def export_consolidated_report(export_report:)
      report_service = ReportService.find(export_report.report_service_id)
      reports = AdvancedReport.where(report_service: report_service).all
      ExportExcel::ExportConsolidatedReportService.call(report_service: report_service, reports: reports,
                                                        start_date: export_report.start_date, end_date: export_report.end_date)
    end

    def upload_file(filename:, source_file:)
      storage_service = StorageServiceClient::FilesApi.new
      response = storage_service.internal_upload_file(file: source_file, original_file_name: filename)
      response.to_hash[:file][:token]
    rescue StorageServiceClient::ApiError => e
      DocytLib.logger.error(e.message)
      update_data_export(state: DATA_EXPORT_ERROR_STATE)
      nil
    end

    def update_data_export(state: DATA_EXPORT_READY_STATE, exported_file_token: nil)
      data_export_api_instance = DocytServerClient::DataExportApi.new
      data_export_api_instance.update_data_export({ data_export: {
                                                    state: state,
                                                    exported_file_token: exported_file_token
                                                  } }, @data_export.id)
    end

    def generate_name_and_business_ids(export_report:) # rubocop:disable Metrics/MethodLength
      case export_report.export_type
      when ExportReport::EXPORT_TYPE_REPORT
        report = Report.find(export_report.report_id)
        { name: "Business Report: #{report.name}", business_ids: [report.report_service.business_id] }
      when ExportReport::EXPORT_TYPE_MULTI_ENTITY_REPORT
        multi_business_report = MultiBusinessReport.find(export_report.multi_business_report_id)
        { name: "Multi Entity Report: #{multi_business_report.name}", business_ids: multi_business_report.business_ids }
      else
        report_service = ReportService.find(export_report.report_service_id)
        { name: 'Business Consolidated Report', business_ids: [report_service.business_id] }
      end
    end
  end
end
