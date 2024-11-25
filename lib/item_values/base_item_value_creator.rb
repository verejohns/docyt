# frozen_string_literal: true

module ItemValues
  class BaseItemValueCreator # rubocop:disable Metrics/ClassLength
    OPERATOR_SUM = 'sum'
    REVENUE_CHART_OF_ACCOUNT_TYPES = ['Income', 'Other Income'].freeze
    EXPENSES_CHART_OF_ACCOUNT_TYPES = ['Expense', 'Other Expense', 'Cost of Goods Sold'].freeze

    # This method will fill the value for the corresponding item_value
    def initialize( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
      report_data:, item:, column:,
      budgets:, standard_metrics:,
      dependent_report_datas:,
      previous_month_report_data:,
      previous_year_report_data:,
      january_report_data_of_current_year:,
      all_business_chart_of_accounts:,
      all_business_vendors:,
      accounting_classes:,
      qbo_ledgers:
    )
      @report_data = report_data
      @item = item
      @column = column
      @report = report_data.report
      @budgets = budgets
      @standard_metrics = standard_metrics
      @dependent_report_datas = dependent_report_datas
      @previous_month_report_data = previous_month_report_data
      @previous_year_report_data = previous_year_report_data
      @january_report_data_of_current_year = january_report_data_of_current_year
      @all_business_chart_of_accounts = all_business_chart_of_accounts
      @all_business_vendors = all_business_vendors
      @accounting_classes = accounting_classes
      @qbo_ledgers = qbo_ledgers
    end

    def call
      raise 'This will be implemented in inherited class.'
    end

    private

    def actual_value_by_identifier(identifier:, column:) # rubocop:disable Metrics/MethodLength
      if identifier.include?('/')
        item_value = actual_item_value_by_identifier_with_dependency(identifier: identifier, column_type: column.type, column_range: column.range, column_year: column.year)
      else
        item_value = @report_data.item_values.detect { |report_item_value| report_item_value.item_identifier == identifier && report_item_value.column_id == column.id.to_s }
        if item_value.nil?
          item = @report.find_item_by_identifier(identifier: identifier)
          creator_instance = ItemValueCreator.new(
            report_data: @report_data,
            budgets: @budgets, standard_metrics: @standard_metrics,
            dependent_report_datas: @dependent_report_datas,
            previous_month_report_data: @previous_month_report_data,
            previous_year_report_data: @previous_year_report_data,
            january_report_data_of_current_year: @january_report_data_of_current_year,
            all_business_chart_of_accounts: @all_business_chart_of_accounts,
            all_business_vendors: @all_business_vendors,
            accounting_classes: @accounting_classes,
            qbo_ledgers: @qbo_ledgers
          )
          item_value = creator_instance.call(item: item, column: column)
        end
      end
      item_value
    end

    def actual_item_value_by_identifier_with_dependency(identifier:, column_type:, column_range:, column_year:)
      identifier_values = identifier.split('/')
      return nil unless identifier_values.length == 2 && @dependent_report_datas.include?(identifier_values[0])

      dependent_report_data = @dependent_report_datas[identifier_values[0]]
      target_column = dependent_report_data.report.columns.find_by(type: column_type, range: column_range, year: column_year)
      dependent_report_data.item_values.detect do |report_item_value|
        report_item_value.item_identifier == identifier_values[1] && report_item_value.column_id == target_column.id.to_s
      end
    end

    def generate_item_value(item:, column:, item_amount: 0.0, accumulated_value_amount: 0.0, dependency_accumulated_value_amount: 0.0, budget_values: []) # rubocop:disable Metrics/ParameterLists
      item_value = @report_data.item_values.new(item_id: item.id.to_s, column_id: column.id.to_s, value: item_amount, item_identifier: item.identifier,
                                                accumulated_value: accumulated_value_amount, dependency_accumulated_value: dependency_accumulated_value_amount,
                                                budget_values: budget_values)
      item_value.generate_column_type_with_infos(item: item, column: column)
      item_value
    end

    def item_expression(item:, target_column_type:)
      stats_formula = item.values_config[target_column_type] if item.values_config.present?
      return nil if stats_formula.blank? || stats_formula['value'].blank? || stats_formula['value']['expression'].blank?

      stats_formula['value']['expression']
    end

    def calculate_value_with_operator(arg1, arg2, operator) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
      value = 0.0
      return value unless arg1 && arg2

      case operator
      when '/'
        value = arg1 / arg2 if arg2.abs > 0.001
      when '+'
        value = arg1 + arg2
      when '-'
        value = arg1 - arg2
      when '%'
        value = arg1 / arg2 * 100.0 if arg2.abs > 0.001
      end
      value.round(2)
    end

    def fetch_metrics_service(business_id:)
      metrics_service_api_instance = DocytServerClient::MetricsServiceApi.new
      metrics_service_api_instance.get_by_business_id(business_id)
    end

    def accumulated_value_from_previous_report_data(current_value:)
      return current_value if @previous_month_report_data.nil?

      previous_month_item_value = @previous_month_report_data.item_values.detect do |report_item_value|
        report_item_value.item_id == @item.id.to_s && report_item_value.column_id == @column.id.to_s
      end
      value = previous_month_item_value&.accumulated_value || 0.0
      value + current_value
    end

    def copy_account_values(src_item_values:, dst_item_value:)
      if @report.vendor_report?
        copy_account_values_for_vendor(src_item_values: src_item_values, dst_item_value: dst_item_value)
      else
        copy_account_values_for_general(src_item_values: src_item_values, dst_item_value: dst_item_value)
      end
    end

    def copy_account_values_for_vendor(src_item_values:, dst_item_value:) # rubocop:disable Metrics/MethodLength
      dst_item_value.item_account_values.destroy_all
      src_item_values.each do |src_item_value|
        src_item_value.item_account_values.each do |src_item_account_value|
          dst_item_account_value = dst_item_value.item_account_values.detect do |av|
            av.chart_of_account_id == src_item_account_value.chart_of_account_id && av.accounting_class_id == src_item_account_value.accounting_class_id
          end
          dst_item_account_value ||= dst_item_value.item_account_values.new(chart_of_account_id: src_item_account_value.chart_of_account_id,
                                                                            accounting_class_id: src_item_account_value.accounting_class_id)
          dst_item_account_value.name = src_item_account_value.name
          dst_item_account_value.value = (dst_item_account_value.value + src_item_account_value.value).round(2)
        end
      end
    end

    def copy_account_values_for_general(src_item_values:, dst_item_value:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength,Metrics/PerceivedComplexity
      dst_item_value.item_account_values.destroy_all
      @item.mapped_item_accounts.each do |item_account|
        business_chart_of_account = @all_business_chart_of_accounts.detect { |category| category.chart_of_account_id == item_account.chart_of_account_id }
        next if business_chart_of_account.nil?

        accounting_class = @accounting_classes.detect { |business_accounting_class| business_accounting_class.id == item_account.accounting_class_id }
        next if item_account.accounting_class_id.present? && accounting_class.nil?

        src_item_account_values = src_item_values.map do |src_item_value|
          src_item_value.item_account_values.detect do |item_account_value|
            item_account_value.chart_of_account_id == item_account.chart_of_account_id && item_account_value.accounting_class_id == item_account.accounting_class_id
          end
        end
        value_amount = src_item_account_values.compact.map(&:value).sum
        dst_item_value.item_account_values.new(chart_of_account_id: item_account.chart_of_account_id,
                                               accounting_class_id: item_account.accounting_class_id,
                                               name: business_chart_of_account.display_name,
                                               value: value_amount.round(2))
      end
    end

    def departmental_item_type
      current_item = @item

      loop do
        break if current_item.parent_item.nil?

        current_item = current_item.parent_item
      end
      current_item.identifier
    end

    def actual_value_with_arg(arg:)
      column_type = arg['column_type'].presence || Column::TYPE_ACTUAL
      column_year = arg['column_year'].presence || @column.year
      source_column = @report.columns.find_by(type: column_type, range: @column.range, year: column_year)
      actual_value_by_identifier(identifier: arg['item_id'], column: source_column)
    end

    def start_date_by_column
      if @report_data.daily? && @column.range == Column::RANGE_MTD
        @report_data.start_date.at_beginning_of_month
      else
        @report_data.start_date
      end
    end
  end
end
