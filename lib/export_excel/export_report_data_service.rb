# frozen_string_literal: true

module ExportExcel
  class ExportReportDataService < ExportBaseService # rubocop:disable Metrics/ClassLength
    def call(report:, start_date:, end_date:)
      @report = report
      @start_date = start_date
      @end_date = end_date
      @total_column = report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      @option_item = report.find_item_by_identifier(identifier: report.view_by_options[0]) if report.view_by_options.present? && report.view_by_options.length.positive?
      @business = get_business(@report.report_service)
      @last_reconciled_date = Date.new(@business.last_reconciled_month_data.year, @business.last_reconciled_month_data.month) if @business.last_reconciled_month_data
      fetch_business_chart_of_accounts(report: report, business_id: @report.report_service.business_id)
      generate_axlsx(report_name_prefix: report.name)
    end

    private

    def fill_work_book(work_book:)
      report_datas_params = { from: @start_date, to: @end_date }
      report_data_query = ReportDatasQuery.new(report: @report, report_datas_params: report_datas_params, include_total: true)
      monthly_report_datas = report_data_query.report_datas
      return if monthly_report_datas.blank?

      add_sheets(work_book: work_book, report_datas: monthly_report_datas)
    end

    def add_sheets(work_book:, report_datas:)
      if report_datas.length > 1
        add_total_sheets(work_book: work_book, report_datas: report_datas)
      elsif report_datas.length == 1
        add_monthly_sheets(work_book: work_book, report_data: report_datas[0])
      end
    end

    def add_total_sheets(work_book:, report_datas:)
      add_total_sheet(work_book: work_book, report_datas: report_datas, name: 'TOTAL') if @report.total_column_visible
      report_datas.each_with_index do |report_data, index|
        next if index.zero?

        sheet_name = "#{report_data.start_date.strftime('%b')}-#{report_data.start_date.strftime('%y')}"
        add_monthly_sheet(work_book: work_book, report_data: report_data, name: sheet_name, view_per_option_item: Report::UPS_REPORTS.exclude?(@report.template_id))
      end
    end

    def add_total_sheet(work_book:, report_datas:, name:)
      work_book.add_worksheet(name: name, page_setup: { fit_to_page: true, fit_to_width: 1, fit_to_height: 1, orientation: :landscape }) do |sheet|
        add_total_sheet_static_header(sheet: sheet, report_datas: report_datas)
        add_total_sheet_data(sheet: sheet, report_datas: report_datas)
        add_note(sheet: sheet)

        sheet.sheet_view do |view|
          view.show_outline_symbols = true
        end
      end
    end

    def add_total_sheet_data(sheet:, report_datas:)
      add_total_sheet_header(sheet: sheet, report_datas: report_datas)
      add_total_to_sheet(sheet: sheet, report_datas: report_datas)
      return if @report.view_by_options.blank?

      add_total_sheet_header(sheet: sheet, report_datas: report_datas)
      add_total_to_sheet(sheet: sheet, report_datas: report_datas, view_per_option_item: true)
    end

    def add_monthly_sheets(work_book:, report_data:)
      add_monthly_sheet(work_book: work_book, report_data: report_data, name: 'Consolidated', view_per_option_item: @report.view_by_options.present?)
      add_monthly_sheet(work_book: work_book, report_data: report_data, name: 'Detailed', show_outline_level: true) if @report.is_a?(AdvancedReport)
    end

    def add_monthly_sheet(work_book:, report_data:, name:, show_outline_level: false, view_per_option_item: false)
      work_book.add_worksheet(name: name,
                              page_setup: { fit_to_page: true, fit_to_width: 1, fit_to_height: 1, orientation: :landscape }) do |sheet|
        add_sheet_static_header(sheet: sheet, report_data: report_data)
        add_monthly_sheet_data(sheet: sheet, report_data: report_data, show_outline_level: show_outline_level, view_per_option_item: view_per_option_item)
        add_note(sheet: sheet)

        sheet.sheet_view do |view|
          view.show_outline_symbols = true
        end
      end
    end

    def add_monthly_sheet_data(sheet:, report_data:, show_outline_level:, view_per_option_item:)
      add_sheet_header(sheet: sheet)
      add_report_to_sheet(sheet: sheet, item_values: report_data.item_values.all, show_outline_level: show_outline_level)
      return unless view_per_option_item

      add_sheet_header(sheet: sheet)
      add_report_to_sheet(sheet: sheet, item_values: report_data.item_values.all, show_outline_level: show_outline_level, view_per_option_item: true)
    end

    def add_sheet_static_header(sheet:, report_data:) # rubocop:disable Metrics/MethodLength
      @blank_ptd_columns = []
      column_widths = []
      @report.columns.where(range: Column::RANGE_CURRENT).order_by(order: :asc).each do |column|
        next if column.name.include?('Budget')

        @blank_ptd_columns << ''
        column_widths << nil
      end
      column_widths << COA_COLUMN_WIDTH
      sheet.add_row(@blank_ptd_columns + ["Company: #{@business.name}"], style: @left_bolden_style, widths: column_widths)
      sheet.add_row(@blank_ptd_columns + [@report.name], style: @left_bolden_style, widths: column_widths)
      sheet.add_row(@blank_ptd_columns + ["As of #{report_data.end_date.strftime('%m/%d/%Y')}"], style: @left_bolden_style, widths: column_widths)
      sheet.add_row(@blank_ptd_columns + ["Last reconciled on #{@last_reconciled_date&.strftime('%m/%Y')}"], style: @left_bolden_style, widths: column_widths)
    end

    def add_sheet_header(sheet:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      ptd_column_names = []
      column_widths = []
      @report.columns.where(range: Column::RANGE_CURRENT).order_by(order: :asc).each do |column|
        next if column.name.include?('Budget')

        ptd_column_names << column.name
        column_widths << nil
      end
      column_widths << COA_COLUMN_WIDTH
      ytd_column_names = []
      @report.columns.where(range: Column::RANGE_YTD).order_by(order: :asc).each do |column|
        next if column.name.include?('Budget')

        ytd_column_names << column.name
        column_widths << nil
      end
      sheet.add_row([])
      if @report.template_id == Report::STORE_MANAGERS_REPORT
        sheet.merge_cells("#{Axlsx.cell_r(0, 5)}:#{Axlsx.cell_r(3, 5)}")
        sheet.merge_cells("#{Axlsx.cell_r(4, 5)}:#{Axlsx.cell_r(7, 5)}")
        sheet.merge_cells("#{Axlsx.cell_r(9, 5)}:#{Axlsx.cell_r(12, 5)}")
        sheet.merge_cells("#{Axlsx.cell_r(13, 5)}:#{Axlsx.cell_r(16, 5)}")
        sheet.add_row(['PTD', '', '', '', 'PTD LY', '', '', '', '', 'YTD', '', '', '', 'YTD LY', '', '', ''], style: @center_bolden_style)
      end
      sheet.add_row(ptd_column_names + [''] + ytd_column_names, style: @center_bolden_style, widths: column_widths)
    end

    def add_note(sheet:)
      sheet.add_row([])
      sheet.add_row(['Note: “-” denotes that data is unavailable for that date/period in Docyt'])
    end

    def add_total_sheet_static_header(sheet:, report_datas:)
      @blank_monthly_columns = []
      report_datas.each do |_report_data|
        @blank_monthly_columns << ''
      end
      sheet.add_row(["Company: #{@business.name}"], style: @left_bolden_style)
      sheet.add_row([@report.name], style: @left_bolden_style, widths: [COA_COLUMN_WIDTH])
      sheet.add_row(["As of #{@end_date.strftime('%m/%d/%Y')}"], style: @left_bolden_style, widths: [COA_COLUMN_WIDTH])
      sheet.add_row(["Last reconciled on #{@last_reconciled_date&.strftime('%m/%Y')}"], style: @left_bolden_style, widths: [COA_COLUMN_WIDTH])
    end

    def add_total_sheet_header(sheet:, report_datas:)
      months_column_names = ['', 'Total']
      column_widths = []
      column_widths << COA_COLUMN_WIDTH
      report_datas.each_with_index do |report_data, index|
        next if index.zero?

        months_column_names << "#{report_data.start_date.strftime('%b')}-#{report_data.start_date.strftime('%y')}"
        column_widths << nil
      end
      sheet.add_row([])
      sheet.add_row(months_column_names, style: @center_bolden_style, widths: column_widths)
    end

    def add_report_to_sheet(sheet:, item_values:, show_outline_level:, view_per_option_item: false) # rubocop:disable Metrics/MethodLength
      @report.items.order_by(order: :asc).each do |item|
        next if view_per_option_item && item.identifier == Item::SUMMARY_ITEM_ID

        sheet.add_row([])
        if item.child_items.present?
          sheet.add_row(@blank_ptd_columns + [item.name] + @blank_ptd_columns, style: @top_border)
          add_one_parent_item(sheet: sheet, item_values: item_values, item: item, show_outline_level: show_outline_level, view_per_option_item: view_per_option_item, child_step: 1)
        else
          add_one_child_item(sheet: sheet, item_values: item_values, item: item, is_section: true,
                             show_outline_level: show_outline_level, view_per_option_item: view_per_option_item)
        end
      end
    end

    def add_total_to_sheet(sheet:, report_datas:, view_per_option_item: false)
      @report.items.order_by(order: :asc).each do |item|
        next if view_per_option_item && item.identifier == Item::SUMMARY_ITEM_ID

        sheet.add_row([])
        if item.child_items.present?
          sheet.add_row([item.name] + @blank_monthly_columns, style: @top_border)
          add_one_parent_item_for_total(sheet: sheet, item: item, report_datas: report_datas, view_per_option_item: view_per_option_item, child_step: 1)
        else
          add_one_child_item_for_total(sheet: sheet, item: item, report_datas: report_datas, is_section: true, view_per_option_item: view_per_option_item)
        end
      end
    end

    def add_one_parent_item(sheet:, item_values:, item:, show_outline_level:, view_per_option_item:, child_step: 0) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      item.child_items.order_by(order: :asc).each do |child_item|
        if child_item.child_items.present?
          if child_item.type_config.present?
            add_one_child_item(sheet: sheet, item_values: item_values, item: child_item, show_outline_level: show_outline_level,
                               view_per_option_item: view_per_option_item, child_step: child_step)
          else
            sheet.add_row(@blank_ptd_columns + [item_name(name: child_item.name, child_step: child_step)])
          end
          add_one_parent_item(sheet: sheet, item_values: item_values, item: child_item, show_outline_level: show_outline_level,
                              view_per_option_item: view_per_option_item, child_step: child_step + 1)
        else
          add_one_child_item(sheet: sheet, item_values: item_values, item: child_item, show_outline_level: show_outline_level,
                             view_per_option_item: view_per_option_item, child_step: child_step)
        end
      end
    end

    def add_one_child_item(sheet:, item_values:, item:, show_outline_level:, view_per_option_item:, is_section: false, child_step: 0) # rubocop:disable Metrics/ParameterLists, Metrics/AbcSize
      return if item.totals && !item.show

      values_styles = values_styles(item: item, is_section: is_section)
      ptd_columns = ptd_column_infos(item: item, item_values: item_values, style: values_styles.first, view_per_option_item: view_per_option_item)
      ytd_columns = ytd_column_infos(item: item, item_values: item_values, style: values_styles.first, view_per_option_item: view_per_option_item)
      sheet.add_row(ptd_columns[:values] + [item_name(name: item.name, child_step: child_step)] + ytd_columns[:values],
                    style: ptd_columns[:styles] + [values_styles.last] + ytd_columns[:styles],
                    widths: ptd_columns[:widths] + [COA_COLUMN_WIDTH] + ytd_columns[:widths])
      add_account_items(sheet: sheet, item_values: item_values.all, item: item) if show_outline_level
    end

    def add_account_items(sheet:, item_values:, item:) # rubocop:disable Metrics/AbcSize
      item.mapped_item_accounts.each do |item_account|
        business_chart_of_account = @business_chart_of_accounts.select { |category| category.chart_of_account_id == item_account.chart_of_account_id }.first
        next if business_chart_of_account.nil?

        ptd_columns = ptd_account_column_infos(item_values: item_values, item_account: item_account, style: @right_normal_style)
        ytd_columns = ytd_account_column_infos(item_values: item_values, item_account: item_account, style: @right_normal_style)
        row = sheet.add_row(ptd_columns[:values] + [business_chart_of_account.display_name] + ytd_columns[:values],
                            style: ptd_columns[:styles] + [@left_normal_style] + ytd_columns[:styles],
                            widths: ptd_columns[:widths] + [COA_COLUMN_WIDTH] + ytd_columns[:widths])
        set_outline_level(row: row, level: 1)
      end
    end

    def add_one_parent_item_for_total(sheet:, item:, report_datas:, view_per_option_item: false, child_step: 0) # rubocop:disable Metrics/MethodLength
      item.child_items.order_by(order: :asc).each do |child_item|
        if child_item.child_items.present?
          if child_item.type_config.present?
            add_one_child_item_for_total(sheet: sheet, item: child_item, report_datas: report_datas, view_per_option_item: view_per_option_item, child_step: child_step)
          else
            sheet.add_row([item_name(name: child_item.name, child_step: child_step)])
          end
          add_one_parent_item_for_total(sheet: sheet, item: child_item, report_datas: report_datas, view_per_option_item: view_per_option_item, child_step: child_step + 1)
        else
          add_one_child_item_for_total(sheet: sheet, item: child_item, report_datas: report_datas, view_per_option_item: view_per_option_item, child_step: child_step)
        end
      end
    end

    def add_one_child_item_for_total(sheet:, item:, report_datas:, view_per_option_item: false, is_section: false, child_step: 0) # rubocop:disable Metrics/ParameterLists
      return if item.totals && !item.show

      values_styles = values_styles(item: item, is_section: is_section)
      total_columns = total_column_infos(item: item, report_datas: report_datas, style: values_styles.first, view_per_option_item: view_per_option_item)
      sheet.add_row([item_name(name: item.name, child_step: child_step)] + total_columns[:values], style: [values_styles.last] + total_columns[:styles], widths: [COA_COLUMN_WIDTH])
    end

    def ptd_account_column_infos(item_values:, item_account:, style:)
      account_column_infos(column_range: Column::RANGE_CURRENT, item_values: item_values, item_account: item_account, style: style)
    end

    def ytd_account_column_infos(item_values:, item_account:, style:)
      account_column_infos(column_range: Column::RANGE_YTD, item_values: item_values, item_account: item_account, style: style)
    end

    def item_values_with(item:, item_values:)
      item_values.select { |item_value| item_value.item_id == item._id.to_s }
    end

    def ptd_column_infos(item:, item_values:, style:, view_per_option_item:)
      column_infos(column_range: Column::RANGE_CURRENT, item: item, item_values: item_values, style: style, view_per_option_item: view_per_option_item)
    end

    def ytd_column_infos(item:, item_values:, style:, view_per_option_item:)
      column_infos(column_range: Column::RANGE_YTD, item: item, item_values: item_values, style: style, view_per_option_item: view_per_option_item)
    end

    def column_infos(column_range:, item:, item_values:, style:, view_per_option_item:) # rubocop:disable Metrics/MethodLength
      column_widths = []
      column_values = []
      column_styles = []
      @report.columns.where(range: column_range).order_by(order: :asc).each do |column|
        next if column.name.include?('Budget')

        info = item_column_info(item_values: item_values, item: item, column: column, style: style, view_per_option_item: view_per_option_item)
        column_values << info[:value]
        column_widths << info[:width]
        column_styles << info[:style]
      end
      { values: column_values, widths: column_widths, styles: column_styles }
    end

    def account_column_infos(column_range:, item_values:, item_account:, style:) # rubocop:disable Metrics/MethodLength
      column_widths = []
      column_values = []
      column_styles = []
      @report.columns.where(range: column_range).order_by(order: :asc).each do |column|
        next if column.name.include?('Budget')

        item_value = item_values.find { |item| item.column_id == column._id.to_s }
        info = account_column_info(item_value: item_value, item_account: item_account, style: style)
        column_values << info[:value]
        column_widths << info[:width]
        column_styles << info[:style]
      end
      { values: column_values, widths: column_widths, styles: column_styles }
    end

    def item_column_info(item_values:, item:, column:, style:, view_per_option_item:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      item_value = item_values.find { |value| value.item_id == item._id.to_s and value.column_id == column._id.to_s }
      return column_info(item_value: item_value, style: style) unless view_per_option_item

      if item.type_config.present? && item.type_config['name'] == Item::TYPE_STATS && item.values_config['actual']['value']['expression']['operator'] == '%'
        return column_info(item_value: item_value, style: style)
      end

      option_value = item_values.find { |value| value.item_id == @option_item&._id.to_s and value.column_id == column._id.to_s }
      option_column_info(item_value: item_value, option_item_value: option_value, column: column, style: style)
    end

    def total_column_infos(item:, report_datas:, style:, view_per_option_item: false)
      column_values = []
      column_styles = []
      report_datas.each do |report_data|
        info = item_column_info(item_values: report_data.item_values.all, item: item, column: @total_column, style: style, view_per_option_item: view_per_option_item)
        column_values << info[:value]
        column_styles << info[:style]
      end
      { values: column_values, styles: column_styles }
    end

    def set_outline_level(row:, level:)
      return if level.zero?

      row.outline_level = level
      row.hidden = true
    end
  end
end
