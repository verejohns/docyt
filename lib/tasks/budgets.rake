# frozen_string_literal: true

namespace :budgets do
  desc 'update budget_items to actual_budget_items, draft_budget_items'
  task update_budget_items_to_draft_budget_items: :environment do |_t, _args|
    BudgetItem.all.each do |budget_item|
      next if budget_item._type.present?

      budget_item._type = DraftBudgetItem.model_name.to_s
      budget_item.save!

      actual_budget_item = ActualBudgetItem.new(
        _type: ActualBudgetItem.model_name.to_s,
        budget: budget_item.budget,
        standard_metric: budget_item.standard_metric,
        chart_of_account_id: budget_item.chart_of_account_id,
        accounting_class_id: budget_item.accounting_class_id,
        position: budget_item.position,
        is_blank: budget_item.is_blank,
        budget_item_values: budget_item.budget_item_values
      )
      actual_budget_item.save!
      puts "updated budget_item type: #{budget_item.inspect}"
    end
  end
end
