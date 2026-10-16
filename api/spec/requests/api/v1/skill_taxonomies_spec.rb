# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Skill taxonomies' do
  let!(:org) { create_org }
  let!(:taxonomy) { create_taxonomy(skill_id: 'SK-TEST-001', label: 'Test Skill') }
  let(:Authorization) { bearer(org) }

  path '/api/v1/skill_taxonomies' do
    get 'List the reference skill taxonomy' do
      tags 'Skill taxonomy'
      security [bearer_auth: []]
      produces 'application/json'
      parameter name: :category, in: :query, required: false, schema: { type: :string, enum: %w[engineering soft_skills product_process] }

      response '200', 'taxonomy' do
        schema type: :object, required: %w[skill_taxonomies],
               properties: { skill_taxonomies: { type: :array, items: { '$ref' => '#/components/schemas/SkillTaxonomy' } } }
        let(:category) { nil }
        run_test! { expect(json['skill_taxonomies'].map { |s| s['skill_id'] }).to include('SK-TEST-001') }
      end

      response '403', 'no valid tenant / role' do
        schema '$ref' => '#/components/schemas/Error'
        let(:category) { nil }
        let(:Authorization) { bearer(org, role: 'student') }
        run_test!
      end
    end
  end

  path '/api/v1/skill_taxonomies/{skill_id}' do
    get 'Get one skill with its L1-L5 anchors' do
      tags 'Skill taxonomy'
      security [bearer_auth: []]
      produces 'application/json'
      parameter name: :skill_id, in: :path, schema: { type: :string }

      response '200', 'skill' do
        schema type: :object, required: %w[skill], properties: { skill: { '$ref' => '#/components/schemas/SkillTaxonomy' } }
        let(:skill_id) { 'SK-TEST-001' }
        run_test!
      end

      response '404', 'unknown skill' do
        schema '$ref' => '#/components/schemas/Error'
        let(:skill_id) { 'SK-NOPE' }
        run_test!
      end
    end
  end
end
