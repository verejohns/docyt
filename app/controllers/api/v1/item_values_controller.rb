# frozen_string_literal: true

module Api
  module V1
    class ItemValuesController < ApplicationController
      def index
        ensure_report_access(report: report, operation: :read)
        report_data = report.report_datas.find_by(start_date: params[:from].to_date, end_date: params[:to].to_date)
        render status: :ok, json: report_data&.item_values, each_serializer: ::ItemValueSerializer
      end

      def show
        ensure_report_access(report: report, operation: :read)
        item_value = report.find_item_value_by_id(params[:id])
        if item_value.present?
          render status: :ok, json: item_value, serializer: ::ItemValueWithStatisticsSerializer, root: 'item_value'
        else
          render status: :unprocessable_entity, json: { errors: I18n.t('item_value_invalid') }
        end
      end

      def by_range
        ensure_report_access(report: report, operation: :read)
        item_values_query = ItemValuesQuery.new(report: report, item_values_params: item_values_params)
        item_values = item_values_query.item_values
        if item_values.blank?
          render status: :ok, json: []
        else
          render status: :ok, json: item_values, each_serializer: ::ItemValueWithStatisticsSerializer
        end
      end

      private

      def item_values_params
        params.permit(:from, :to, :item_id)
      end
    end
  end
end
