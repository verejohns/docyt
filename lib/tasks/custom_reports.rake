# frozen_string_literal: true

namespace :custom_reports do # rubocop:disable Metrics/BlockLength
  desc 'Remove duplicate reports with same template_id'
  task remove_duplicate_report: :environment do |_t, _args|
    Report.all.each do |report|
      report = Report.find_by(id: report.id)
      next if report.blank?

      Report.where(report_service_id: report.report_service_id, template_id: report.template_id).where.not(id: report.id).destroy_all
    end
  end

  desc 'Re-update the waiting reports'
  task re_update_waiting_report: :environment do |_t, _args|
    Report.all.each do |report|
      if Report::UPDATE_STATES_QUEUED.include?(report.update_state) || report.update_state == Report::UPDATE_STATE_STARTED
        ReportFactory.force_update_without_condition(report: report)
      end
    end
  end

  desc "Update column's name field with templates"
  task update_column_name: :environment do |_t, _args|
    Report.all.each do |report|
      json_path = Rails.root.join("app/assets/jsons/templates/#{report.template_id}.json")
      next unless File.exist?(json_path) || report.template_id == Report::DEPARTMENT_REPORT

      columns = report.template_id == Report::DEPARTMENT_REPORT ? ReportFactory::DEPARTMENT_REPORT_COLUMNS : JSON.parse(File.read(json_path))['columns']
      report.columns.each do |column|
        temp = columns.detect do |col|
          (col['type'] || col[:type]) == column.type && (col['range'] || col[:range]) == column.range && (col['year'] || col[:year]) == column.year
        end
        name = temp[:name] || temp['name']
        column.update!(name: name)
      end
    end
  end

  desc 'Update report items'
  task update_report_items: :environment do |_t, _args|
    Report.all.each do |report|
      case report
      when AdvancedReport
        ReportFactory.sync_report_infos(report: report)
      when ProfitAndLossReport
        ProfitAndLossReportFactory.sync_report_infos(report: report)
      end
    end
  end

  desc 'Update Revenue Accounting Reports'
  task update_revenue_accounting_reports: :environment do |_t, _args|
    Report.where(template_id: Report::REVENUE_ACCOUNTING_REPORT).all.each do |report|
      report.report_datas.update_all(dependency_digests: {}) # rubocop:disable Rails/SkipsModelValidations
      report.refresh_all_report_datas
    end
  end

  desc 'Update Revenue Reports'
  task update_revenue_reports: :environment do |_t, _args|
    Report.where(template_id: Report::REVENUE_REPORT).all.each do |report|
      report.report_datas.update_all(dependency_digests: {}) # rubocop:disable Rails/SkipsModelValidations
      report.refresh_all_report_datas
    end
  end

  desc 'Force refactor all Revenue Reports'
  task force_refactor_all_revenue_reports: :environment do |_t, _args|
    Report.where(template_id: Report::REVENUE_REPORT).all.each(&:refill_report)
  end

  desc 'Update UPS Balance Sheet Reports'
  task update_ups_balance_sheets: :environment do |_t, _args|
    Report.where(template_id: Report::UPS_ADVANCED_BALANCE_SHEET_REPORT).all.each do |report|
      report.report_datas.update_all(dependency_digests: {}) # rubocop:disable Rails/SkipsModelValidations
      report.refresh_all_report_datas
    end
  end

  desc 'Update all Reports from bookkeeping_start_date'
  task update_reports_from_bookkeeping_start_date: :environment do |_t, _args|
    Report.all.each do |report|
      report.report_datas.update_all(dependency_digests: {}) # rubocop:disable Rails/SkipsModelValidations
      report.refresh_all_report_datas
    end
  end

  desc 'Update UPS Owners Reports'
  task update_ups_owners_reports: :environment do |_t, _args|
    Report.where(template_id: Report::UPS_ADVANCED_OWNERS_REPORT).all.each do |report|
      report.report_datas.update_all(dependency_digests: {}) # rubocop:disable Rails/SkipsModelValidations
      report.refresh_all_report_datas
    end
  end

  desc 'Remove ItemAccounts with accounting_class_id=0'
  task remove_invalid_item_accounts: :environment do |_t, _args|
    AdvancedReport.all.each do |report|
      item_accounts = report.all_item_accounts.select { |item_account| item_account.accounting_class_id.present? && item_account.accounting_class_id.zero? }
      item_accounts.each do |item_account|
        item_account.update!(accounting_class_id: nil)
      end
    end
  end
end
