# frozen_string_literal: true

class BudgetsQuery < BaseService
  def initialize(report_service:, params:)
    super()
    @params = params
    @report_service = report_service
    @order_column = params[:order_column] || 'created_at'
    @order_direction = params[:order_direction] || 'desc'
  end

  def all_budgets
    query = @report_service.budgets
    budgets = common_sort_query(query)
    users = get_users(user_ids: budgets.map(&:creator_id))
    BudgetsDecorator.decorate_collection(budgets, context: { users: users })
  end

  private

  def common_sort_query(query)
    query.order_by([@order_column, @order_direction])
  end
end
