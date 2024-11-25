# frozen_string_literal: true

class VendorReportFactory < ReportFactory
  private

  def sync_items_with_template(report:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Lint/UnusedMethodArgument
    total_item_name = 'Total Expenses'
    total_item_identifier = 'vendor_total_expenses'
    total_item_order = 1_000_000
    sub_items_for_total = []
    type_config_stats = { name: 'stats' }
    total_vendor_item = report.items.detect { |item| item.identifier == total_item_identifier }
    if total_vendor_item.present?
      total_vendor_item.update!(name: total_item_name, order: total_item_order, totals: false, type_config: type_config_stats)
    else
      total_vendor_item = report.items.create!(name: total_item_name, order: total_item_order, identifier: total_item_identifier, totals: false, type_config: type_config_stats)
    end
    all_item_ids = [total_vendor_item.id.to_s]
    item_order = 0
    type_config_general_ledger = { name: 'quickbooks_ledger' }
    @business_vendors.each do |business_vendor|
      vendor_item = report.items.detect { |item| item.identifier == business_vendor.name }
      if vendor_item.present?
        vendor_item.update!(name: business_vendor.name, order: item_order, totals: false, type_config: type_config_general_ledger)
      else
        vendor_item = report.items.create!(name: business_vendor.name, order: item_order, identifier: business_vendor.name, totals: false, type_config: type_config_general_ledger)
      end
      item_order += 1
      all_item_ids << vendor_item.id.to_s
      values_config = {
        percentage: {
          value: {
            expression: {
              operator: '%',
              arg1: {
                item_id: vendor_item.identifier
              },
              arg2: {
                item_id: total_vendor_item.identifier
              }
            }
          }
        }
      }
      sub_items_for_total << { id: vendor_item.identifier, negative: false }
      vendor_item.update(values_config: values_config)
    end

    total_values_config = {
      actual: {
        value: {
          expression: {
            operator: 'sum',
            arg: {
              sub_items: sub_items_for_total
            }
          }
        }
      },
      percentage: {
        value: {
          expression: {
            operator: '%',
            arg1: {
              item_id: total_vendor_item.identifier
            },
            arg2: {
              item_id: total_vendor_item.identifier
            }
          }
        }
      }
    }
    total_vendor_item.update(values_config: total_values_config)
    report.items.where.not(_id: { '$in': all_item_ids }).destroy_all
  end
end
