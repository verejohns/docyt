# frozen_string_literal: true

namespace :standard_metrics do
  desc 'Create or Update Standard Metrics'
  task create_or_update_standard_metrics: :environment do |_t, _args|
    standard_metric = StandardMetric.find_by(name: 'Rooms Available to sell')
    if standard_metric.present?
      standard_metric.update!(type: 'Available Rooms', code: 'rooms_available')
    else
      StandardMetric.create!(name: 'Rooms Available to sell', type: 'Available Rooms', code: 'rooms_available')
    end
    standard_metric = StandardMetric.find_by(name: 'Rooms Sold')
    if standard_metric.present?
      standard_metric.update!(type: 'Sold Rooms', code: 'rooms_sold')
    else
      StandardMetric.create!(name: 'Rooms Sold', type: 'Sold Rooms', code: 'rooms_sold')
    end
  end

  desc 'Update name from "Rooms Available" to "Rooms Available to sell"'
  task update_name_of_standard_metrics: :environment do |_t, _args|
    standard_metric = StandardMetric.find_by(name: 'Rooms Available')
    standard_metric.update!(name: 'Rooms Available to sell') if standard_metric.present?
    puts "updated standard metric name from 'Rooms Available' to #{standard_metric.name}"
  end
end
