# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Vacancies' do
  let!(:org) { create_org }
  let!(:other_org) { create_org(scheme: 'org-b') }
  let(:Authorization) { bearer(org) }

  path '/api/v1/vacancies' do
    get 'List vacancies of the current tenant' do
      tags 'Vacancies'
      security [bearer_auth: []]
      produces 'application/json'
      parameter name: :page, in: :query, required: false, schema: { type: :integer }

      response '200', 'a page of vacancies' do
        schema type: :object, required: %w[vacancies meta],
               properties: {
                 vacancies: { type: :array, items: { '$ref' => '#/components/schemas/Vacancy' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }
        let(:page) { 1 }
        before do
          create_vacancy(org, role_title: 'Mine')
          create_vacancy(other_org, role_title: 'Not mine')
        end

        run_test! { expect(json['vacancies'].map { |v| v['role_title'] }).to eq(['Mine']) }
      end
    end

    post 'Create a vacancy' do
      tags 'Vacancies'
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object, required: %w[vacancy], properties: { vacancy: { '$ref' => '#/components/schemas/VacancyInput' } }
      }

      response '201', 'created' do
        schema type: :object, required: %w[vacancy], properties: { vacancy: { '$ref' => '#/components/schemas/VacancyWithSkills' } }
        let(:body) do
          { vacancy: { role_title: 'Staff Engineer', culture_dimensions: 'Ownership',
                       vacancy_skills_attributes: [{ skill_id: 'SK-TEST-001', skill_label: 'Test Skill', expected_level: 4 }] } }
        end

        run_test! { expect(json['vacancy']['skills'].first['expected_level']).to eq(4) }
      end

      response '422', 'role title missing' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) { { vacancy: { role_title: '' } } }
        run_test!
      end

      response '422', 'expected level out of range' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) do
          { vacancy: { role_title: 'X', vacancy_skills_attributes: [{ skill_label: 'Test Skill', expected_level: 6 }] } }
        end
        run_test!
      end
    end
  end

  path '/api/v1/vacancies/{id}' do
    parameter name: :id, in: :path, schema: { type: :integer }

    get 'Get a vacancy with its skills' do
      tags 'Vacancies'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'vacancy' do
        schema type: :object, required: %w[vacancy], properties: { vacancy: { '$ref' => '#/components/schemas/VacancyWithSkills' } }
        let(:id) { create_vacancy(org).id }
        run_test!
      end

      response '404', 'vacancy of another tenant' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { create_vacancy(other_org).id }
        run_test!
      end
    end

    put 'Update a vacancy' do
      tags 'Vacancies'
      description 'Nested skills follow Rails nested-attributes rules: a skill is removed only with ' \
                  '`{ id, _destroy: true }`; leaving it out of the payload keeps it (audit R-03).'
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object, required: %w[vacancy], properties: { vacancy: { '$ref' => '#/components/schemas/VacancyInput' } }
      }

      let(:vacancy) { create_vacancy(org, skills: [['SK-TEST-001', 'Test Skill', 3], [nil, 'Custom', 2]]) }
      let(:id) { vacancy.id }

      response '200', 'updated; omitted skills are kept' do
        schema type: :object, required: %w[vacancy], properties: { vacancy: { '$ref' => '#/components/schemas/VacancyWithSkills' } }
        let(:body) { { vacancy: { role_title: 'Renamed' } } }
        run_test! { expect(json['vacancy']['skills'].size).to eq(2) }
      end

      response '200', 'a skill is removed only with _destroy' do
        schema type: :object, required: %w[vacancy], properties: { vacancy: { '$ref' => '#/components/schemas/VacancyWithSkills' } }
        let(:body) { { vacancy: { role_title: 'Renamed', vacancy_skills_attributes: [{ id: vacancy.vacancy_skills.first.id, _destroy: true }] } } }
        run_test! { expect(json['vacancy']['skills'].size).to eq(1) }
      end
    end

    delete 'Delete a vacancy' do
      tags 'Vacancies'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'deleted' do
        schema '$ref' => '#/components/schemas/Message'
        let(:id) { create_vacancy(org).id }
        run_test! { expect(Vacancy.unscoped.exists?(id)).to be(false) }
      end
    end
  end
end
