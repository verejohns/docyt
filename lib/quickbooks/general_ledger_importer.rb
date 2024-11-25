# frozen_string_literal: true

module Quickbooks
  class GeneralLedgerImporter
    include DocytLib::Helpers::PerformanceHelpers

    GENERAL_LEDGER_URL = 'reports/GeneralLedger'
    BALANCE_SHEET_URL = 'reports/BalanceSheet'
    GENERAL_LEDGER_COLUMNS_ACC = 'tx_date,txn_type,doc_num,memo,vend_name,split_acc,subt_nat_amount,subt_nat_home_amount,subt_nat_amount_nt,subt_nat_amount_home_nt,account_name,klass_name' # rubocop:disable Layout/LineLength
    GENERAL_LEDGER_ACCOUNT_TYPES = 'Expense,CostOfGoodsSold,Income,OtherExpense,OtherIncome,Bank,AccountsReceivable,OtherCurrentAsset,FixedAsset,OtherAsset,AccountsPayable,CreditCard,OtherCurrentLiability,LongTermLiability,Equity' # rubocop:disable Layout/LineLength
    GENERAL_LEDGER_VENDOR_ACCOUNT_TYPES = 'Expense,OtherExpense,Income,OtherIncome'
    GENERAL_LEDGER_EXPENSES_ACCOUNT_TYPES = 'Expense,CostOfGoodsSold,OtherExpense'
    GENERAL_LEDGER_REVENUE_ACCOUNT_TYPES = 'Income,OtherIncome'
    GENERAL_LEDGER_BANK_ACCOUNT_TYPE = 'Bank'
    GENERAL_LEDGER_ACCOUNTS_PAYABLE_ACCOUNT_TYPE = 'AccountsPayable'
    MINOR_VERSION = 57

    class << self
      def import(report_service:, general_ledger_class:, start_date:, end_date:, qbo_authorization:)
        new.import(report_service: report_service, general_ledger_class: general_ledger_class, qbo_authorization: qbo_authorization, start_date: start_date, end_date: end_date)
      end

      delegate :fetch_qbo_token, to: :new
    end

    def import(report_service:, general_ledger_class:, start_date:, end_date:, qbo_authorization:)
      qbo_api_instance = qbo_access_token(qbo_authorization.second_token)
      general_ledger_class.where(report_service: report_service, start_date: start_date, end_date: end_date).delete_all
      general_ledger = general_ledger_class.create!(report_service: report_service, start_date: start_date, end_date: end_date)
      line_item_details_raw_data = fetch_qbo_general_ledger(
        qbo_company_id: qbo_authorization.uid,
        qbo_api_instance: qbo_api_instance,
        general_ledger: general_ledger
      )
      analyze_qbo_general_ledger(general_ledger: general_ledger, line_item_details_raw_data: line_item_details_raw_data)
      general_ledger
    end
    apm_method :import

    def fetch_qbo_token(report_service)
      business_api_instance = DocytServerClient::BusinessApi.new
      response = business_api_instance.get_qbo_connection(report_service.business_id)
      response.cloud_service_authorization
    rescue DocytServerClient::ApiError => e
      DocytLib.logger.debug(e.message)
      nil
    end

    private

    def qbo_access_token(access_token)
      qbo_client = OAuth2::Client.new(
        DocytLib.config.quickbooks.client_id, DocytLib.config.quickbooks.client_secret,
        {
          site: 'https://appcenter.intuit.com',
          authorize_url: '/connect/oauth2',
          token_url: 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer',
          redirect_uri: DocytLib.config.quickbooks.redirect_uri
        }
      )
      OAuth2::AccessToken.new(qbo_client, access_token)
    end

    def fetch_qbo_general_ledger(qbo_company_id:, qbo_api_instance:, general_ledger:)
      url = generate_url(qbo_company_id: qbo_company_id, general_ledger: general_ledger)
      DocytLib.logger.info("QBO request: GET #{url}")
      response = qbo_api_instance.get(url, headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' })
      response.body
    end

    def analyze_qbo_general_ledger(general_ledger:, line_item_details_raw_data:)
      analyzer_class = if general_ledger.is_a?(Quickbooks::BalanceSheetGeneralLedger)
                         BalanceSheetAnalyzer
                       else
                         GeneralLedgerAnalyzer
                       end
      analyzer_class.analyze(general_ledger: general_ledger, line_item_details_raw_data: line_item_details_raw_data)
    end

    def generate_url(qbo_company_id:, general_ledger:) # rubocop:disable Metrics/MethodLength
      start_date = general_ledger.start_date
      end_date = general_ledger.end_date
      search_query = "accounting_method=Accrual&minorversion=#{MINOR_VERSION}"

      if general_ledger.is_a?(Quickbooks::BalanceSheetGeneralLedger)
        url = "#{DocytLib.config.quickbooks.api_base_uri}/#{qbo_company_id}/#{BALANCE_SHEET_URL}"
        url += "?start_date=#{start_date}&end_date=#{end_date}&#{search_query}"
      else
        search_query += "&columns=#{GENERAL_LEDGER_COLUMNS_ACC}"
        account_type = qbo_account_type(general_ledger: general_ledger)
        url = "#{DocytLib.config.quickbooks.api_base_uri}/#{qbo_company_id}/#{GENERAL_LEDGER_URL}"
        url += "?start_date=#{start_date}&end_date=#{end_date}&#{search_query}&account_type=#{account_type}"
      end
      url
    end

    def qbo_account_type(general_ledger:) # rubocop:disable Metrics/MethodLength
      case general_ledger.class
      when Quickbooks::CommonGeneralLedger
        GENERAL_LEDGER_ACCOUNT_TYPES
      when Quickbooks::BankGeneralLedger
        GENERAL_LEDGER_BANK_ACCOUNT_TYPE
      when Quickbooks::AccountsPayableGeneralLedger
        GENERAL_LEDGER_ACCOUNTS_PAYABLE_ACCOUNT_TYPE
      when Quickbooks::ExpensesGeneralLedger
        GENERAL_LEDGER_EXPENSES_ACCOUNT_TYPES
      when Quickbooks::RevenueGeneralLedger
        GENERAL_LEDGER_REVENUE_ACCOUNT_TYPES
      when Quickbooks::VendorGeneralLedger
        GENERAL_LEDGER_VENDOR_ACCOUNT_TYPES
      end
    end
  end
end
