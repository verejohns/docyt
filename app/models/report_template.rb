# frozen_string_literal: true

class ReportTemplate
  JSON_SCHEMA_PATH = Rails.root.join('app/assets/schemas/report-schema.json')
  class Column
    include ActiveModel::Model

    attr_accessor :type, :range, :year, :name
  end

  class Item
    include ActiveModel::Model

    attr_accessor :id, :name, :parent_id, :totals, :show, :negative_for_total, :negative, :depth_diff, :account_type,
                  :type, :values, :balance_sheet, :_description
  end

  include ActiveModel::Model

  attr_accessor :id, :name, :rank, :standard_category_ids, :draft, :period_type, :factory_class,
                :items, :columns, :enabled_budget_compare, :depends_on, :multi_entity_columns,
                :view_by_options, :missing_transactions_calculation_disabled, :total_column_visible,
                :accounting_class_check_disabled, :enabled_blank_value_for_metric, :edit_mapping_disabled

  def columns # rubocop:disable Lint/DuplicateMethods
    @columns.map { |c| Column.new(c) }
  end

  def items # rubocop:disable Lint/DuplicateMethods
    @items.map { |i| Item.new(i) }
  end

  def dependencies; end

  def self.from_file(file)
    raise 'Template is incorrect.' unless File.exist?(file)

    json = JSON.parse(File.read(file))
    schema = JSON.parse(File.read(JSON_SCHEMA_PATH))
    errors = JSON::Validator.fully_validate(schema, json)
    if errors.any?
      DocytLib.logger.error("Unable to load report #{file}: JSON validation errors:")
      DocytLib.logger.error(errors.join("\n"))
      raise "Unable to load report #{file}"
    end
    new(json)
  end

  def self.find_by(template_id:)
    return nil if template_id == Report::DEPARTMENT_REPORT

    json_path = Rails.root.join("app/assets/jsons/templates/#{template_id}.json")
    from_file(json_path)
  end

  def factory_class # rubocop:disable Lint/DuplicateMethods
    return @factory_class.constantize if @factory_class

    ReportFactory
  end
end
