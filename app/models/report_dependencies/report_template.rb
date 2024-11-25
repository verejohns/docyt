# frozen_string_literal: true

module ReportDependencies
  class ReportTemplate < Base
    def calculate_digest
      return nil if @report_data.report.template_id.blank? || @report_data.report.departmental_report?

      json_path = Rails.root.join("app/assets/jsons/templates/#{@report_data.report.template_id}.json")
      DocytLib::Encryption::Digest.dataset_digest([File.read(json_path)])
    end

    def refresh; end
  end
end
