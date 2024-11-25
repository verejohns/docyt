# frozen_string_literal: true

class TemplatesQuery
  TEMPLATES_DIR = Rails.root.join('app/assets/jsons/templates')
  HOSPITALITY_STANDARD_CATEGORY_ID = 9

  def initialize(query_params = nil)
    @query_params = query_params || {}
  end

  def self.all_template_files
    Dir.glob(File.join(TEMPLATES_DIR, '**', '*.json'))
  end

  def template_from_json(template_json)
    { id: template_json['id'],
      name: template_json['name'],
      standard_category_ids: template_json['standard_category_ids'],
      draft: template_json['draft'],
      depends_on: template_json['depends_on'],
      rank: template_json['rank'],
      view_by_options: template_json['view_by_options'] }
  end

  def template(template_id:)
    file_path = File.join(TEMPLATES_DIR, "#{template_id}.json")
    return {} unless File.file?(file_path)

    template_json = JSON.parse(File.read(file_path))
    template_from_json(template_json)
  end

  def templates
    standard_category_ids = @query_params[:standard_category_id].present? ? [@query_params[:standard_category_id]] : @query_params[:standard_category_ids] || []
    standard_category_ids = standard_category_ids.map(&:to_i)
    template_array = all_templates.select do |template|
      standard_category_ids.map { |standard_category_id| template[:standard_category_ids].include?(standard_category_id) }.any?
    end
    if standard_category_ids.include?(HOSPITALITY_STANDARD_CATEGORY_ID)
      template_array << { id: Report::DEPARTMENT_REPORT.to_s, name: 'Departmental Report', draft: false, depends_on: nil, rank: 17 }
    end
    template_array.sort_by! { |k| k[:rank] }
  end

  def all_templates
    template_array = []

    self.class.all_template_files.each do |file_path|
      template_json = JSON.parse(File.read(file_path))
      next unless template_json['standard_category_ids']

      template_array << template_from_json(template_json)
    end
    template_array.sort_by! { |k| k[:rank] }.sort_by! { |k| k[:standard_category_ids].first }
  end
end
