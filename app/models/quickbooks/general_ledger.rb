# frozen_string_literal: true

module Quickbooks
  # This is base class of all general_ledgers
  class GeneralLedger
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic

    belongs_to :report_service, class_name: 'ReportService', inverse_of: :general_ledgers
    embeds_many :line_item_details, class_name: 'Quickbooks::LineItemDetail', inverse_of: :general_ledger

    field :start_date, type: Date
    field :end_date, type: Date

    validates :start_date, presence: true
    validates :end_date, presence: true

    index({ report_service_id: 1, start_date: 1, end_date: 1, _type: 1 })
    index({ 'line_item_details.qbo_id': 1 })
  end
end
