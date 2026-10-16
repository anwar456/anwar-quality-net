# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Assessments' do
  let!(:org) { create_org }
  let!(:other_org) { create_org(scheme: 'org-b') }
  let(:Authorization) { bearer(org) }

  skill_input = lambda do |extra = {}|
    { skill_id: 'SK-TEST-001', skill_label: 'Test Skill', is_custom: false, expected_level: 3, display_order: 0,
      l1_anchor: 'a', l2_anchor: 'b', l3_anchor: 'c', l4_anchor: 'd', l5_anchor: 'e' }.merge(extra)
  end

  path '/api/v1/assessments' do
    get 'List assessments of the current tenant' do
      tags 'Assessments'
      security [bearer_auth: []]
      produces 'application/json'
      parameter name: :page, in: :query, required: false, schema: { type: :integer }

      response '200', 'a page of assessments (tenant scoped)' do
        schema type: :object, required: %w[assessments meta],
               properties: {
                 assessments: { type: :array, items: { '$ref' => '#/components/schemas/Assessment' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }
        let(:page) { 1 }
        before do
          create_assessment(org, name: 'Mine')
          create_assessment(other_org, name: 'Not mine')
        end

        run_test! do
          expect(json['assessments'].map { |a| a['name'] }).to eq(['Mine'])
          expect(json['meta']['total_count']).to eq(1)
        end
      end

      response '403', 'no token: the tenant cannot be resolved, so the request is refused before authentication (a 401 would be expected)' do
        schema '$ref' => '#/components/schemas/Error'
        let(:page) { nil }
        let(:Authorization) { nil }
        run_test!
      end

      response '403', 'candidate-role token' do
        schema '$ref' => '#/components/schemas/Error'
        let(:page) { nil }
        let(:Authorization) { bearer(org, role: 'student') }
        run_test!
      end
    end

    post 'Create an assessment' do
      tags 'Assessments'
      description 'Creates the assessment and queues generation of the interviewer system prompt ' \
                  '(asynchronous, although the response always says `system_prompt_generated: true`).'
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object, required: %w[assessment], properties: { assessment: { '$ref' => '#/components/schemas/AssessmentInput' } }
      }

      response '201', 'created' do
        schema type: :object, required: %w[assessment system_prompt_generated],
               properties: {
                 assessment: { type: :object, required: %w[id name time_limit_min tenant_id],
                               properties: { id: { type: :integer }, name: { type: :string }, tenant_id: { type: :integer } } },
                 system_prompt_generated: { type: :boolean }
               }
        let(:body) { { assessment: { name: 'QA Lead', time_limit_min: 45, language: 'id', assessment_skills_attributes: [skill_input.call] } } }

        run_test! do
          created = Assessment.unscoped.find(json['assessment']['id'])
          expect(created.tenant_id).to eq(org.id)
          expect(created.assessment_skills.count).to eq(1)
          expect(SystemPromptGeneratorWorker.jobs.size).to eq(1)
        end
      end

      response '422', 'time limit not allowed' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) { { assessment: { name: 'QA Lead', time_limit_min: 7 } } }
        run_test!
      end
    end
  end

  path '/api/v1/assessments/{id}' do
    parameter name: :id, in: :path, schema: { type: :integer }

    get 'Get an assessment with its skills' do
      tags 'Assessments'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'assessment' do
        schema type: :object, required: %w[assessment], properties: { assessment: { '$ref' => '#/components/schemas/AssessmentWithSkills' } }
        let(:id) { create_assessment(org).id }
        run_test! { expect(json['assessment']['skills'].size).to eq(1) }
      end

      response '404', 'not found, or belongs to another tenant' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { create_assessment(other_org).id }
        run_test!
      end
    end

    put 'Update an assessment' do
      tags 'Assessments'
      description 'Nested skills follow Rails nested-attributes rules: send `id` to update, no `id` to add, ' \
                  '`{ id, _destroy: true }` to remove. Skills that are simply left out of the payload are kept.'
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object, required: %w[assessment], properties: { assessment: { '$ref' => '#/components/schemas/AssessmentInput' } }
      }

      let(:assessment) { create_assessment(org, skills: [['SK-TEST-001', 'Test Skill'], [nil, 'Custom Skill']]) }
      let(:id) { assessment.id }

      response '200', 'updated' do
        schema type: :object, required: %w[assessment system_prompt_generated],
               properties: { assessment: { '$ref' => '#/components/schemas/AssessmentWithSkills' }, system_prompt_generated: { type: :boolean } }
        let(:body) { { assessment: { name: 'Renamed', time_limit_min: 60 } } }

        run_test! do
          expect(json['assessment']['name']).to eq('Renamed')
          expect(json['assessment']['skills'].size).to eq(2) # omitted skills are kept
        end
      end

      response '200', 'a skill is removed only with _destroy' do
        schema type: :object, required: %w[assessment], properties: { assessment: { '$ref' => '#/components/schemas/AssessmentWithSkills' } }
        let(:body) do
          { assessment: { name: 'Renamed', time_limit_min: 30,
                          assessment_skills_attributes: [{ id: assessment.assessment_skills.first.id, _destroy: true }] } }
        end

        run_test! { expect(json['assessment']['skills'].size).to eq(1) }
      end
    end

    delete 'Delete an assessment' do
      tags 'Assessments'
      description 'An assessment that already has candidate sessions cannot be deleted: the answer is 409 and the ' \
                  'assessment is kept.'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'deleted (assessment without sessions)' do
        schema '$ref' => '#/components/schemas/Message'
        let(:id) { create_assessment(org).id }
        run_test! { expect(Assessment.unscoped.exists?(id)).to be(false) }
      end

      response '409', 'refused: the assessment has candidate sessions' do
        schema '$ref' => '#/components/schemas/Error'
        let(:assessment) { create_assessment(org) }
        let(:id) { assessment.id }
        before { create_interview(assessment) }
        run_test! { expect(Assessment.unscoped.exists?(id)).to be(true) }
      end
    end
  end
end
