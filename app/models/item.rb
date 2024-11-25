# frozen_string_literal: true

class Item
  include Mongoid::Document

  TYPE_METRIC = 'metric'
  TYPE_QUICKBOOKS_LEDGER = 'quickbooks_ledger'
  TYPE_STATS = 'stats'
  TYPE_REFERENCE = 'reference'

  CALCULATION_TYPE_CONFIG = 'calculation_type'
  GENERAL_LEDGER_CALCULATION_TYPE = 'general_ledger'
  BANK_GENERAL_LEDGER_CALCULATION_TYPE = 'bank_general_ledger'
  TAX_COLLECTED_VALUE_CALCULATION_TYPE = 'tax_collected_value'
  BS_BALANCE_CALCULATION_TYPE = 'bs_balance'
  BS_PRIOR_DAY_CALCULATION_TYPE = 'bs_prior_day'
  BS_NET_CHANGE_CALCULATION_TYPE = 'bs_net_change'
  DEBITS_ONLY_CALCULATION_TYPE = 'debits_only'
  CREDITS_ONLY_CALCULATION_TYPE = 'credits_only'

  EXCLUDE_LEDGERS_CONFIG = 'exclude_ledgers'
  EXCLUDE_LEDGERS_BANK = 'bank'
  EXCLUDE_LEDGERS_BANK_AND_AP = 'bank_and_accounts_payable'

  REVENUE = 'revenue'
  EXPENSES = 'expenses'
  PROFIT = 'profit'

  SUMMARY_ITEM_ID = 'summary'

  PL_ACC_TYPES = ['Expense', 'Other Expense', 'Cost of Goods Sold', 'Income', 'Other Income'].freeze
  BS_ACC_TYPES = [
    'Fixed Asset', 'Equity', 'Accounts Payable', 'Accounts Receivable',
    'Long Term Liability', 'Other Current Liability', 'Credit Card',
    'Other Current Asset', 'Other Asset', 'Bank'
  ].freeze

  field :name, type: String
  field :order, type: Integer
  field :identifier, type: String
  field :totals, type: Boolean, default: false
  field :show, type: Boolean, default: true
  field :type_config, type: Object
  field :values_config, type: Object
  field :negative, type: Boolean, default: false
  field :negative_for_total, type: Boolean, default: false
  field :depth_diff, type: Integer, default: 0
  field :account_type, type: String

  validates :name, presence: true
  validates :order, presence: true
  validates :identifier, presence: true

  embedded_in :report, class_name: 'Report'
  embeds_many :item_accounts, class_name: 'ItemAccount'
  embedded_in :parent_item, class_name: 'Item', inverse_of: :child_items
  embeds_many :child_items, class_name: 'Item', inverse_of: :parent_item

  def item_account_count
    if totals && parent_item.present?
      parent_item.all_item_accounts.count
    else
      item_accounts.count
    end
  end

  def all_item_accounts
    if child_items.present?
      item_accounts + child_items.sort_by(&:order).map(&:all_item_accounts).flatten
    else
      item_accounts
    end
  end

  def find_child_by_identifier(identifier:)
    item = child_items.detect { |child_item| child_item.identifier == identifier }
    return item if item.present?

    child_items.each do |child_item|
      item = child_item.find_child_by_identifier(identifier: identifier)
      return item if item.present?
    end
    nil
  end

  def find_child_by_id(id)
    item = child_items.detect { |child_item| child_item._id.to_s == id }
    return item if item.present?

    child_items.each do |child_item|
      item = child_item.find_child_by_id(id)
      return item if item.present?
    end
    nil
  end

  def releated_to_metric?
    if child_items.present?
      child_items.any?(&:releated_to_metric?)
    else
      type_config.present? && type_config['name'] == TYPE_METRIC
    end
  end

  def include_bs_prior_day_item?
    return true if type_config.present? && type_config[Item::CALCULATION_TYPE_CONFIG] == Item::BS_PRIOR_DAY_CALCULATION_TYPE

    child_items.each do |child_item|
      return true if child_item.include_bs_prior_day_item?
    end
    false
  end

  def mapped_item_accounts
    if type_config.present? && type_config['use_mapping'].present?
      report = get_report(parent_item) if report.nil?
      item = report.find_item_by_identifier(identifier: type_config['use_mapping']['item_id'])
      return item.item_accounts if item.present?

      return []
    end
    item_accounts
  end

  def total_item
    child_items.each do |child_item|
      return child_item if child_item.totals
    end
    nil
  end

  private

  def get_report(item)
    if item.parent_item.present?
      get_report(item.parent_item)
    else
      item.report
    end
  end
end
