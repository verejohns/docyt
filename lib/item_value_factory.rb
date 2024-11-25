# frozen_string_literal: true

class ItemValueFactory < BaseService # rubocop:disable Metrics/ClassLength
  include DocytLib::Helpers::PerformanceHelpers

  def generate_batch( # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
    report_data:,
    dependent_report_datas:,
    all_business_chart_of_accounts:,
    qbo_ledgers:, january_report_data_of_current_year:, all_business_vendors: [],
    accounting_classes: []
  )
    @report_data = report_data
    @report = report_data.report
    @dependent_report_datas = dependent_report_datas
    @all_business_chart_of_accounts = all_business_chart_of_accounts
    @all_business_vendors = all_business_vendors
    @accounting_classes = accounting_classes
    @qbo_ledgers = qbo_ledgers
    @january_report_data_of_current_year = january_report_data_of_current_year
    @budgets = Budget.where(report_service: @report.report_service, year: @report_data.start_date.year)
    @standard_metrics = StandardMetric.all

    fill_item_values
    fill_budget_ids

    report_data.save!
  end
  apm_method :generate_batch

  private

  def columns # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    @columns ||= [
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_VARIANCE, range: Column::RANGE_CURRENT),
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD),
      @report.detect_column(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD),
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_VARIANCE, range: Column::RANGE_CURRENT),
      @report.detect_column(type: Column::TYPE_VARIANCE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_VARIANCE, range: Column::RANGE_YTD),
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_VARIANCE, range: Column::RANGE_YTD),
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_MTD, year: Column::YEAR_CURRENT)
    ].compact
  end

  def previous_month_report_data
    return nil if @report_data.daily?

    @previous_month_report_data ||= @report.report_datas.where(period_type: ReportData::PERIOD_MONTHLY, start_date: @report_data.start_date - 1.month,
                                                               end_date: @report_data.start_date - 1.day).first
  end

  def previous_year_report_data
    return nil if @report_data.daily?

    start_date = @report_data.start_date - 1.year
    case @report_data.period_type
    when ReportData::PERIOD_MONTHLY
      end_date = Date.new(start_date.year, start_date.month, -1)
    when ReportData::PERIOD_ANNUALLY
      end_date = Date.new(start_date.year, 12, -1)
    end
    @previous_year_report_data ||= @report.report_datas.where(period_type: @report_data.period_type, start_date: start_date, end_date: end_date).first
  end

  def fill_item_values # rubocop:disable Metrics/MethodLength
    item_value_creator = ItemValues::ItemValueCreator.new(
      report_data: @report_data,
      budgets: @budgets, standard_metrics: @standard_metrics,
      dependent_report_datas: @dependent_report_datas,
      previous_month_report_data: previous_month_report_data,
      previous_year_report_data: previous_year_report_data,
      january_report_data_of_current_year: @january_report_data_of_current_year,
      all_business_chart_of_accounts: @all_business_chart_of_accounts,
      all_business_vendors: @all_business_vendors,
      accounting_classes: @accounting_classes,
      qbo_ledgers: @qbo_ledgers
    )
    columns.each do |column|
      next if @report_data.daily? && (column.range == Column::RANGE_YTD)

      items.each do |item|
        item_value_creator.call(column: column, item: item)
      end
    end
  end

  def items # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    reference_items = []
    metric_items = []
    qbo_general_ledger_items = []
    stats_items = []
    total_items = []
    sorted_tree_items.each do |tree_item|
      item = tree_item[:item]
      if item.totals
        total_items << item
      elsif item.type_config.present?
        case item.type_config['name']
        when Item::TYPE_METRIC
          metric_items << item
        when Item::TYPE_REFERENCE
          reference_items << item
        when Item::TYPE_QUICKBOOKS_LEDGER
          qbo_general_ledger_items << item
        when Item::TYPE_STATS
          stats_items << item
        end
      end
    end
    metric_items + reference_items + qbo_general_ledger_items + total_items + stats_items
  end

  def sorted_tree_items # rubocop:disable Metrics/MethodLength
    tree_items = @report.items.map { |item| { item: item, visited: false } }
    index = 0
    loop do
      tree_item = tree_items[index]
      break if tree_item.blank?

      item = tree_item[:item]
      if tree_item[:visited]
        index += 1
        next
      else
        tree_item[:visited] = true
        child_tree_items = item.child_items.map { |child_item| { item: child_item, visited: false } }
        tree_items.insert(index, *child_tree_items)
      end
    end
    tree_items
  end

  def fill_budget_ids
    @report_data.budget_ids = @budgets.map { |budget| budget.id.to_s }
  end
end
