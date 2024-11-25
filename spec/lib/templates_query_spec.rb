# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplatesQuery do
  describe '.all_template_files' do
    it 'lists all files' do
      files = described_class.all_template_files
      expect(files.length).to be > 10
      expect(files).to include(Rails.root.join('app/assets/jsons/templates/schedule_6.json').to_s)
    end
  end

  describe '#template' do
    it 'returns a template' do
      result = described_class.new.template(template_id: 'administrative_general')
      expect(result[:standard_category_ids]).to eq([9])
    end
  end

  describe '#templates' do
    subject(:templates) { described_class.new(query_params).templates }

    context 'when standard_category_id is Hospitality industry' do
      let(:query_params) { { standard_category_id: 9 } }

      it 'returns templates for Hospitality' do
        expect(templates.size).to eq(21)
      end
    end

    context 'when standard_category_id is UPS Industry' do
      let(:query_params) { { standard_category_id: 8 } }

      it 'returns templates for UPS industry' do
        expect(templates.size).to eq(4)
      end
    end

    context 'when standard_category_ids is Hospitality and UPS Industry' do
      let(:query_params) { { standard_category_ids: [8, 9] } }

      it 'returns templates for Hospitality and UPS Industry' do
        expect(templates.size).to eq(24)
      end
    end
  end

  describe '#all_templates' do
    it 'returns all templates' do
      result = described_class.new.all_templates
      expect(result.size).to be > 10
    end
  end
end
