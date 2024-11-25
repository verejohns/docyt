# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: budgets
#
#  id                   :string
#  report_service_id    :integer
#  name                 :string
#  year                 :integer
#  total_amount         :float
#  creator_id           :integer
#  created_at           :datetime
#

require 'rails_helper'

RSpec.describe BudgetSerializer do
  let(:budget) { Struct.new(:report_service_id, :name, :year, :total_amount).new(132, 'name', 2022, 123.4) }

  it 'contains budget information in json' do
    expect(budget['report_service_id']).to eq(132)
    expect(budget['name']).to eq('name')
    expect(budget['year']).to eq(2022)
    expect(budget['total_amount']).to eq(123.4)
  end
end
