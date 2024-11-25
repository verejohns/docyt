# frozen_string_literal: true

module Api
  module V1
    class ItemsController < ApplicationController
      def create
        ensure_report_access(report: report, operation: :write)
        item_result = ItemFactory.create(parent_item: current_item, name: params[:name])
        if item_result.success?
          render status: :created, json: item_result.item, serializer: ::ItemSerializer
        else
          render status: 422, json: { errors: item_result.errors }
        end
      end

      def update
        ensure_report_access(report: report, operation: :write)
        current_item.update!(name: params[:name])
        render status: :ok, json: current_item, serializer: ::ItemSerializer
      end

      def index
        ensure_report_access(report: report, operation: :read)
        render status: :ok, json: report.items.order_by(order: :asc), each_serializer: ::ItemSerializer
      end

      def destroy
        ensure_report_access(report: report, operation: :write)
        current_item.destroy!
        render status: :ok, json: { success: true }
      end

      def by_multi_business_report
        ensure_multi_business_report(multi_business_report: multi_business_report)
        render status: :ok, json: multi_business_report.all_items, each_serializer: ::ItemSerializer
      end

      private

      def current_item
        report.find_item_by_id(id: (params[:id] || params[:parent_item_id]))
      end

      def multi_business_report
        @multi_business_report ||= MultiBusinessReport.where(_id: params[:multi_business_report_id]).first
      end
    end
  end
end
