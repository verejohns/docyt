# frozen_string_literal: true

class AdvancedReportFactory < ReportFactory
  attr_accessor(:report)

  def create(report_service:, report_params:, current_user:) # rubocop:disable Metrics/MethodLength
    if report_params[:template_id] != Report::DEPARTMENT_REPORT
      report_tempalte = ReportTemplate.find_by(template_id: report_params[:template_id])
      add_error('This template is not ready.') and return if report_tempalte.draft
    end

    @report = AdvancedReport.new(
      report_service: report_service,
      template_id: report_params[:template_id],
      name: report_params[:name]
    )
    unless @report.save
      @errors = @report.errors
      return
    end
    update_report_users(report: @report, current_user: current_user)
    fetch_accounting_classes(report_service.business_id) if report.template_id == Report::DEPARTMENT_REPORT
    sync_report_infos(report: @report)
    ItemAccountFactory.load_default_mapping(report: @report) if @report.enabled_default_mapping
  end
end
