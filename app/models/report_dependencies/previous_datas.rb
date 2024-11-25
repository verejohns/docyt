# frozen_string_literal: true

module ReportDependencies
  class PreviousDatas < Base
    def calculate_digest
      return nil if @report_data.daily?

      previous_datas = @report_data
                       .report
                       .report_datas
                       .where(start_date: { '$lt' => @report_data.start_date }, period_type: @report_data.period_type)
                       .pluck(:updated_at)
      DocytLib::Encryption::Digest.dataset_digest(previous_datas)
    end

    def refresh; end
  end
end
