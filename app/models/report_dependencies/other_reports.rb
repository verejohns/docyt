# frozen_string_literal: true

module ReportDependencies
  class OtherReports < Base
    def calculate_digest
      DocytLib::Encryption::Digest.dataset_digest(@report_data.dependent_report_datas.values, [:updated_at])
    end

    def refresh; end
  end
end
