# frozen_string_literal: true

module ReportDependencies
  class Base
    def initialize(report_data)
      @report_data = report_data
    end

    def has_changed? # rubocop:disable Naming/PredicateName
      calculate_digest != current_digest
    end

    def current_digest
      @report_data.dependency_digests[self.class.to_s]
    end

    def calculate_digest
      raise 'Override in the child class'
    end

    def refresh
      raise 'Override in the child class'
    end
  end
end
