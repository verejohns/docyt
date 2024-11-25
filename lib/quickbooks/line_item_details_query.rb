# frozen_string_literal: true

module Quickbooks
  class LineItemDetailsQuery < BaseLineItemDetailsQuery # rubocop:disable Metrics/ClassLength
    TOTAL_TYPE = 'total'
    BEGINNING_BALANCE_TYPE = 'beginning_balance'

    def initialize(report:, item:, params:) # rubocop:disable Lint/MissingSuper
      @params = params
      @report = report
      @item = item
    end

    def by_period(start_date:, end_date:, include_total: false) # rubocop:disable Metrics/MethodLength
      fetch_business_information(@report.report_service)
      fetch_business_vendors(business_id: @report.report_service.business_id) if @report.vendor_report?
      general_ledgers = @report.report_service.general_ledgers
                               .where(_type: { '$in': general_ledger_types })
                               .where(start_date: { '$gte' => start_date }, end_date: { '$lte' => end_date })
                               .all
      line_item_details = []
      general_ledgers.each { |general_ledger| line_item_details += extract_line_item_details(general_ledger: general_ledger) }
      line_item_details = add_beginning_and_total_item(line_item_details: line_item_details, start_date: start_date.to_date) if include_total
      line_item_details = paginate(line_item_details)
      return [] if line_item_details.blank?

      fetch_value_links(business_id: @report.report_service.business_id, line_item_details: line_item_details)
    end

    private

    def extract_line_item_details(general_ledger:) # rubocop:disable Metrics/MethodLength
      line_item_details = general_ledger.line_item_details
      if @params[:chart_of_account_id].present?
        line_item_details = add_condition_for_category(
          line_item_details: line_item_details,
          chart_of_account_id: @params[:chart_of_account_id],
          accounting_class_id: @params[:accounting_class_id]
        )
        if @report.vendor_report?
          business_vendor = @business_vendors.detect { |bv| bv.name == @item.identifier }
          line_item_details = line_item_details.select { |lid| lid.vendor == business_vendor.qbo_name }
        end
      end
      filter_by_calculation_type(line_item_details: line_item_details, start_date: general_ledger.start_date, end_date: general_ledger.end_date)
    end

    def filter_by_calculation_type(line_item_details:, start_date:, end_date:) # rubocop:disable Metrics/MethodLength
      return line_item_details if @item.type_config.blank?

      case @item.type_config[Item::CALCULATION_TYPE_CONFIG]
      when Item::BANK_GENERAL_LEDGER_CALCULATION_TYPE
        line_item_details = combine_line_item_details_from_bank_general_ledger(
          common_line_item_details: line_item_details,
          start_date: start_date, end_date: end_date
        )
      when Item::TAX_COLLECTED_VALUE_CALCULATION_TYPE
        line_item_details = combine_line_item_details_for_tax_general_ledger(
          common_line_item_details: line_item_details,
          start_date: start_date, end_date: end_date
        )
      end
      line_item_details
    end

    def add_beginning_and_total_item(line_item_details:, start_date:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      result_line_item_details = []
      if @item.type_config.present? &&
         [Item::BS_BALANCE_CALCULATION_TYPE, Item::BS_PRIOR_DAY_CALCULATION_TYPE, Item::BS_NET_CHANGE_CALCULATION_TYPE].include?(@item.type_config[Item::CALCULATION_TYPE_CONFIG])

        balance_sheet_general_ledger = Quickbooks::BalanceSheetGeneralLedger.find_by(
          report_service: @report.report_service,
          start_date: start_date - 1.month, end_date: start_date - 1.day
        )
        beginning_balance_amount = 0.00
        if balance_sheet_general_ledger.present? && @params[:chart_of_account_id].present?
          business_chart_of_account = @all_business_chart_of_accounts.select { |category| category.chart_of_account_id == @params[:chart_of_account_id].to_i }.first
          previous_line_item_details = balance_sheet_general_ledger.line_item_details&.select { |lid| lid.chart_of_account_qbo_id == business_chart_of_account.qbo_id }
          beginning_balance_amount = previous_line_item_details.sum(&:amount).round(2) || 0.00
        end
        result_line_item_details << LineItemDetail.new(transaction_type: BEGINNING_BALANCE_TYPE, amount: beginning_balance_amount)
      end
      result_line_item_details += line_item_details
      result_line_item_details << LineItemDetail.new(transaction_type: TOTAL_TYPE, amount: result_line_item_details.map(&:amount).sum.round(2) || 0.00)
      result_line_item_details
    end

    def add_condition_for_category(line_item_details:, chart_of_account_id:, accounting_class_id:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      business_chart_of_account = @all_business_chart_of_accounts.select { |category| category.chart_of_account_id == chart_of_account_id.to_i }.first
      line_item_details = line_item_details.select { |line_item_detail| line_item_detail.chart_of_account_qbo_id == business_chart_of_account&.qbo_id }
      return line_item_details if @report.accounting_class_check_disabled

      accounting_class = @accounting_classes.select { |business_accounting_class| business_accounting_class.id == accounting_class_id&.to_i }.first
      line_item_details.select { |line_item_detail| line_item_detail.accounting_class_qbo_id == accounting_class&.external_id }
    end

    def general_ledger_types
      if @report.departmental_report?
        ['Quickbooks::ExpensesGeneralLedger', 'Quickbooks::RevenueGeneralLedger']
      elsif @report.vendor_report?
        ['Quickbooks::VendorGeneralLedger']
      else
        ['Quickbooks::CommonGeneralLedger']
      end
    end

    def combine_line_item_details_from_bank_general_ledger(common_line_item_details:, start_date:, end_date:)
      bank_general_ledger = @report.report_service.general_ledgers
                                   .where(_type: Quickbooks::BankGeneralLedger.to_s)
                                   .where(start_date: { '$gte' => start_date }, end_date: { '$lte' => end_date })
                                   .first
      bank_general_ledger.line_item_details.select do |lid|
        common_line_item_details.any? { |common_lid| common_lid.transaction_type == lid.transaction_type && common_lid.qbo_id == lid.qbo_id }
      end
    end

    def combine_line_item_details_for_tax_general_ledger(common_line_item_details:, start_date:, end_date:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      bank_general_ledger = @report.report_service.general_ledgers
                                   .where(_type: Quickbooks::BankGeneralLedger.to_s)
                                   .where(start_date: { '$gte' => start_date }, end_date: { '$lte' => end_date })
                                   .first
      common_line_item_details.reject do |common_lid|
        bank_general_ledger.line_item_details.any? do |lid|
          common_lid.transaction_type == lid.transaction_type &&
            common_lid.qbo_id == lid.qbo_id
        end
      end
      return common_line_item_details unless @item.type_config[Item::EXCLUDE_LEDGERS_CONFIG] == Item::EXCLUDE_LEDGERS_BANK_AND_AP

      ap_general_ledger = @report.report_service.general_ledgers
                                 .where(_type: Quickbooks::AccountsPayableGeneralLedger.to_s)
                                 .where(start_date: { '$gte' => start_date }, end_date: { '$lte' => end_date })
                                 .first
      common_line_item_details.reject do |common_lid|
        ap_general_ledger.line_item_details.any? do |lid|
          (common_lid.transaction_type == lid.transaction_type) && (common_lid.qbo_id == lid.qbo_id)
        end
      end
    end

    def paginate(line_item_details, page_size = ITEM_DETAILS_PER_PAGE)
      page_num = (@params[:page] || 1).to_i
      first_index = (page_num - 1) * page_size
      line_item_details.slice(first_index, page_size)
    end
  end
end
