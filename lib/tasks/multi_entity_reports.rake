# frozen_string_literal: true

namespace :multi_entity_reports do
  # This rake task must be run when multi_entity_columns filed is updated in report template file.
  desc 'Create columns for all Multi Entity reports with template'
  task create_columns: :environment do |_t, _args|
    MultiBusinessReport.all.each do |report|
      report_template = ReportTemplate.find_by(template_id: report.template_id)
      columns = report_template.multi_entity_columns.presence || MultiBusinessReport::DEFAULT_COLUMNS
      report.columns.delete_all
      columns.each { |column| report.columns.create!(type: column['type'] || column[:type], name: column['name'] || column[:name]) }

      puts "The columns was updated for this multi entity report: #{report.id}"
    end
  end
end
