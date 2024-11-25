# frozen_string_literal: true

module Api
  module V1
    class ItemAccountValuesController < ApplicationController
      def show
        ensure_report_access(report: report, operation: :read)
        item_value = report.find_item_value_by_id(params[:item_value_id])
        if item_value.present?
          item_account_value = item_value.item_account_values.detect { |iav| iav._id.to_s == params[:id] }
          render status: :ok, json: item_account_value, serializer: ::ItemAccountValueSerializer, root: 'item_account_value'
        else
          render status: :unprocessable_entity, json: { errors: I18n.t('item_value_invalid') }
        end
      end

      def line_item_details # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        ensure_report_access(report: report, operation: :read)
        item_value = report.find_item_value_by_id(params[:item_value_id])
        if item_value.present?
          item_account_value = item_value.item_account_values.detect { |iav| iav._id.to_s == params[:id] }
          line_item_details_query = ::Quickbooks::LineItemDetailsQuery.new(
            report: item_value.report_data.report,
            item: item_value.report_data.report.find_item_by_identifier(identifier: item_value.item_identifier),
            params: { chart_of_account_id: item_account_value.chart_of_account_id,
                      accounting_class_id: item_account_value.accounting_class_id,
                      page: params[:page] }
          )
          date_range = item_value.date_range
          line_item_details = line_item_details_query.by_period(start_date: date_range.first, end_date: date_range.last, include_total: true)

          render status: :ok, json: line_item_details, each_serializer: ::Quickbooks::LineItemDetailSerializer, root: 'line_item_details'
        else
          render status: :unprocessable_entity, json: { errors: I18n.t('item_value_invalid') }
        end
      end
    end
  end
end
