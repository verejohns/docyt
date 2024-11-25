# frozen_string_literal: true

module ExportExcel
  class ExportBaseService < BaseService # rubocop:disable Metrics/ClassLength
    attr_accessor :report_file_path

    COA_COLUMN_WIDTH = 50
    EXPORT_INDENTATION = 2

    protected

    def generate_axlsx(report_name_prefix:) # rubocop:disable Metrics/MethodLength
      @report_file_path = if @is_daily
                            excel_file_path(report_name_prefix: report_name_prefix, start_date: @current_date, end_date: @current_date)
                          else
                            excel_file_path(report_name_prefix: report_name_prefix, start_date: @start_date, end_date: @end_date)
                          end
      p = Axlsx::Package.new
      p.workbook do |work_book|
        generate_work_book_styles(work_book: work_book)
        fill_work_book(work_book: work_book)
      end
      p.serialize(@report_file_path)
    end

    def excel_file_path(report_name_prefix:, start_date:, end_date:)
      report_folder_location = './tmp/multi_business_report_data_export/'
      FileUtils.mkdir_p(report_folder_location) unless File.directory?(report_folder_location)
      report_name_prefix = report_name_prefix.dup.gsub(/[^0-9A-Za-z]/, '-')
      report_file_path = if start_date + 1.month < end_date
                           report_folder_location + "#{report_name_prefix}-#{start_date.year}-#{start_date.month}-#{end_date.year}-#{end_date.month}.xlsx"
                         else
                           report_folder_location + "#{report_name_prefix}-#{end_date.year}-#{end_date.month}.xlsx"
                         end
      system("rm -rf #{report_file_path}")
      report_file_path
    end

    def generate_work_book_styles(work_book:) # rubocop:disable Metrics/MethodLength
      work_book.styles do |style|
        @left_normal_style = style.add_style(alignment: { horizontal: :left, vertical: :center, wrap_text: true })
        @right_normal_style = style.add_style(alignment: { horizontal: :right, vertical: :center, wrap_text: true })
        @normal_actual_style = style.add_style(alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '$* #,##0.00;$* (#,##0.00);$* 0.00;@')
        @normal_percentage_style = style.add_style(alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00%')
        @normal_variance_style = style.add_style(alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00')
        @left_bolden_style = style.add_style(b: true, alignment: { horizontal: :left, vertical: :center, wrap_text: true })
        @right_bolden_style = style.add_style(b: true, alignment: { horizontal: :right, vertical: :center, wrap_text: true })
        @center_bolden_style = style.add_style(b: true, alignment: { horizontal: :center, vertical: :center, wrap_text: true })
        @bolden_actual_style = style.add_style(b: true, alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '$* #,##0.00;$* (#,##0.00);$* 0.00;@')
        @bolden_percentage_style = style.add_style(b: true, alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00%')
        @bolden_variance_style = style.add_style(b: true, alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00')
        @top_border = style.add_style(b: true, border: { style: :thin, color: 'FF000000', edges: %i[top] }, alignment: { horizontal: :left, vertical: :center, wrap_text: true })
        @top_actual_border = style.add_style(b: true, border: { style: :thin, color: 'FF000000', edges: %i[top] },
                                             alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '$* #,##0.00;$* (#,##0.00);$* 0.00;@')
        @top_percentage_border = style.add_style(b: true, border: { style: :thin, color: 'FF000000', edges: %i[top] },
                                                 alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00%')
        @top_variance_border = style.add_style(b: true, border: { style: :thin, color: 'FF000000', edges: %i[top] },
                                               alignment: { horizontal: :left, vertical: :center, wrap_text: true }, format_code: '#,##')
      end
    end

    def fill_work_book(work_book:) end

    def column_info(item_value:, style:)
      column_type = item_value&.column_type
      column_info_with(value: item_value&.value, column_type: column_type, style: style)
    end

    def column_info_with(value:, column_type:, style:) # rubocop:disable Metrics/MethodLength
      column_value = case column_type
                     when Column::TYPE_PERCENTAGE
                       (value ? (value / 100.0) : '-')
                     else
                       (value || '-')
                     end
      column_width = nil
      column_style = case column_type
                     when Column::TYPE_PERCENTAGE
                       percentage_column_style(style: style)
                     when Column::TYPE_VARIANCE
                       variance_column_style(style: style)
                     else
                       actual_column_style(style: style)
                     end

      { value: column_value, width: column_width, style: column_style }
    end

    def option_column_info(item_value:, option_item_value:, column:, style:)
      return { value: '-', width: nil, style: style } unless column.type == Column::TYPE_ACTUAL && item_value && option_item_value

      option_value = option_item_value.value
      value = option_value.abs.positive? ? item_value.value / option_value : 0.0
      column_info_with(value: value, column_type: item_value.column_type, style: style)
    end

    def account_column_info(item_value:, item_account:, style:)
      column_type = item_value&.column_type
      return { value: '-', width: nil, style: actual_column_style(style: style) } unless column_type == Column::TYPE_ACTUAL

      account_value = item_value&.item_account_values&.find_by(chart_of_account_id: item_account.chart_of_account_id,
                                                               accounting_class_id: item_account.accounting_class_id)
      column_value = account_value&.value || '-'
      { value: column_value, width: nil, style: actual_column_style(style: style) }
    end

    def percentage_column_style(style:)
      case style
      when @right_normal_style
        @normal_percentage_style
      when @right_bolden_style
        @bolden_percentage_style
      else
        @top_percentage_border
      end
    end

    def actual_column_style(style:)
      case style
      when @right_normal_style
        @normal_actual_style
      when @right_bolden_style
        @bolden_actual_style
      else
        @top_actual_border
      end
    end

    def variance_column_style(style:)
      case style
      when @right_normal_style
        @normal_variance_style
      when @right_bolden_style
        @bolden_variance_style
      else
        @top_variance_border
      end
    end

    def item_name(name:, child_step:)
      return name if child_step.zero?

      name.indent(child_step * EXPORT_INDENTATION)
    end

    def values_styles(item:, is_section:) # rubocop:disable Metrics/MethodLength
      values_column_style = if is_section
                              @top_border
                            else
                              (item.totals ? @right_bolden_style : @right_normal_style)
                            end
      name_column_style = if is_section
                            @top_border
                          else
                            (item.totals ? @left_bolden_style : @left_normal_style)
                          end
      [values_column_style, name_column_style]
    end
  end
end
