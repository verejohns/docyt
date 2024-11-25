# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::TemplatesController do
  describe 'GET #index' do
    subject(:index_response) do
      get :index, params: params
    end

    let(:params) do
      {
        standard_category_id: 9
      }
    end

    it 'returns 200 response and templates for industry' do
      index_response
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body, symbolize_names: true)
      expect(json_response[:templates].length).to be > 10
    end
  end

  describe 'GET #all_templates' do
    subject(:all_templates_response) do
      get :all_templates, params: params
    end

    let(:params) do
      {
        standard_category_id: 9
      }
    end

    it 'returns 200 response and all templates' do
      all_templates_response
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body, symbolize_names: true)
      expect(json_response[:templates].length).to be > 10
    end
  end
end
