# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Portfolios, overrides and fit/gap' do
  let!(:org) { create_org }
  let(:assessment) { create_assessment(org) }
  let(:session) { create_interview(assessment, status: 'active') }
  let(:Authorization) { bearer(org) }

  def build_report(portfolio, vacancy, comparisons: nil)
    FitGapReport.create!(
      portfolio: portfolio, vacancy: vacancy, overall_narrative: 'Overall.', culture_narrative: 'Culture.',
      skill_comparisons: comparisons || [{ skill_label: 'Test Skill', skill_id: 'SK-TEST-001', expected_level: 3,
                                          candidate_level: 3, result: 'match', delta: 0, confidence: 'high' }]
    )
  end

  path '/api/v1/sessions/{id}/portfolio' do
    parameter name: :id, in: :path, schema: { type: :integer }, description: 'Session id'

    get 'Portfolio of a finished session' do
      tags 'Portfolio'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'generated portfolio' do
        schema type: :object, required: %w[portfolio], properties: { portfolio: { '$ref' => '#/components/schemas/Portfolio' } }
        let(:id) { session.id }
        before { create_portfolio(session) }

        run_test! do
          skill = json['portfolio']['skills'].first
          expect(skill['ai_level']).to eq(3)
          expect(skill['ai_confidence']).to eq('high')
        end
      end

      response '202', 'still generating, or not created yet' do
        schema type: :object, required: %w[status], properties: { status: { type: :string, example: 'generating' } }
        let(:id) { session.id }
        run_test!
      end
    end
  end

  path '/api/v1/sessions/{id}/portfolio/regenerate' do
    parameter name: :id, in: :path, schema: { type: :integer }, description: 'Session id'

    post 'Retry a failed portfolio generation' do
      tags 'Portfolio'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'queued' do
        schema type: :object, required: %w[message portfolio],
               properties: { message: { type: :string }, portfolio: { '$ref' => '#/components/schemas/Portfolio' } }
        let(:id) { session.id }
        before { create_portfolio(session, status: 'failed') }

        run_test! do
          expect(Portfolio.find_by(session_id: id).generation_status).to eq('pending')
          expect(PortfolioGeneratorWorker.jobs.size).to eq(1)
        end
      end

      response '422', 'only a failed portfolio can be regenerated' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { session.id }
        before { create_portfolio(session, status: 'complete') }
        run_test!
      end
    end
  end

  path '/api/v1/portfolios/{id}/export' do
    parameter name: :id, in: :path, schema: { type: :integer }, description: 'Portfolio id'

    get 'Export a portfolio (JSON or PDF)' do
      tags 'Portfolio'
      security [bearer_auth: []]
      parameter name: :format, in: :query, required: false, schema: { type: :string, enum: %w[json pdf] }
      parameter name: :vacancy_id, in: :query, required: false, schema: { type: :integer },
                description: 'Include the fit/gap report for this vacancy'

      response '200', 'JSON export' do
        produces 'application/json'
        schema type: :object, required: %w[exported_at portfolio],
               properties: { exported_at: { type: :string }, portfolio: { '$ref' => '#/components/schemas/Portfolio' },
                             fit_gap_report: { type: :object, nullable: true } }
        let(:portfolio_and_skill) { create_portfolio(session) }
        let(:id) { portfolio_and_skill.first.id }
        let(:format) { 'json' }
        let(:vacancy_id) { nil }
        run_test! { expect(json['portfolio']['id']).to eq(id) }
      end

      response '200', 'PDF export' do
        produces 'application/pdf'
        let(:portfolio_and_skill) { create_portfolio(session) }
        let(:id) { portfolio_and_skill.first.id }
        let(:format) { 'pdf' }
        let(:vacancy_id) { nil }
        run_test! { expect(response.body).to start_with('%PDF') }
      end

      response '422', 'portfolio not complete' do
        produces 'application/json'
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { create_portfolio(session, status: 'failed').first.id }
        let(:format) { 'json' }
        let(:vacancy_id) { nil }
        run_test!
      end
    end
  end

  path '/api/v1/portfolio_skills/{id}/override' do
    parameter name: :id, in: :path, schema: { type: :integer }, description: 'Portfolio skill id'

    post 'Assessor overrides the AI level of a skill' do
      tags 'Portfolio'
      description 'Creates the override, or updates it if one exists. Cached fit/gap reports of the portfolio are ' \
                  'deleted and queued for regeneration.'
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object, required: %w[override],
        properties: { override: { type: :object, required: %w[override_level],
                                  properties: { override_level: { type: :integer, minimum: 1, maximum: 5 },
                                                assessor_notes: { type: :string } } } }
      }

      let(:portfolio_and_skill) { create_portfolio(session, level: 2) }
      let(:id) { portfolio_and_skill.last.id }

      response '201', 'override created' do
        schema type: :object, required: %w[override], properties: { override: { '$ref' => '#/components/schemas/Override' } }
        let(:body) { { override: { override_level: 4, assessor_notes: 'Strong system design' } } }

        run_test! do
          expect(json['override']['ai_level']).to eq(2)
          expect(json['override']['override_level']).to eq(4)
        end
      end

      response '200', 'existing override updated' do
        schema type: :object, required: %w[override], properties: { override: { '$ref' => '#/components/schemas/Override' } }
        let(:body) { { override: { override_level: 5 } } }
        before { portfolio_and_skill.last.create_assessor_override!(ai_level: 2, override_level: 3, overridden_by: 1) }
        run_test! { expect(json['override']['override_level']).to eq(5) }
      end

      response '422', 'level out of range' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) { { override: { override_level: 9 } } }
        run_test!
      end
    end
  end

  path '/api/v1/portfolios/{id}/fitgap' do
    parameter name: :id, in: :path, schema: { type: :integer }, description: 'Portfolio id'

    post 'Request (or fetch the cached) fit/gap report for a vacancy' do
      tags 'Fit/gap'
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object, properties: { fitgap: { type: :object, properties: { vacancy_id: { type: :integer } } } }
      }

      let(:portfolio_and_skill) { create_portfolio(session) }
      let(:portfolio) { portfolio_and_skill.first }
      let(:vacancy) { create_vacancy(org) }
      let(:id) { portfolio.id }

      response '200', 'cached report' do
        schema type: :object, required: %w[report], properties: { report: { '$ref' => '#/components/schemas/FitGapReport' } }
        let(:body) { { fitgap: { vacancy_id: vacancy.id } } }
        before { build_report(portfolio, vacancy) }
        run_test! { expect(json['report']['skill_comparisons'].first['expected_level']).to eq(3) }
      end

      response '202', 'generation queued' do
        schema type: :object, required: %w[status message], properties: { status: { type: :string }, message: { type: :string } }
        let(:body) { { fitgap: { vacancy_id: vacancy.id } } }
        run_test! { expect(FitGapGeneratorWorker.jobs.size).to eq(1) }
      end

      response '404', 'vacancy not found in this tenant' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) { { fitgap: { vacancy_id: 999_999 } } }
        run_test!
      end

      response '422', 'vacancy_id missing' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) { { fitgap: {} } }
        run_test!
      end
    end
  end

  path '/api/v1/portfolios/{id}/regenerate_fitgap' do
    parameter name: :id, in: :path, schema: { type: :integer }, description: 'Portfolio id'

    post 'Delete the cached fit/gap report and queue a new one' do
      tags 'Fit/gap'
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object, required: %w[vacancy_id], properties: { vacancy_id: { type: :integer } }
      }

      response '202', 'queued' do
        schema type: :object, required: %w[status], properties: { status: { type: :string }, message: { type: :string } }
        let(:portfolio) { create_portfolio(session).first }
        let(:vacancy) { create_vacancy(org) }
        let(:id) { portfolio.id }
        let(:body) { { vacancy_id: vacancy.id } }
        before { build_report(portfolio, vacancy) }

        run_test! do
          expect(FitGapReport.where(portfolio_id: portfolio.id).count).to eq(0)
          expect(FitGapGeneratorWorker.jobs.size).to eq(1)
        end
      end
    end
  end

  path '/api/v1/portfolios/{id}/fitgap/{vacancy_id}' do
    parameter name: :id, in: :path, schema: { type: :integer }, description: 'Portfolio id'
    parameter name: :vacancy_id, in: :path, schema: { type: :integer }

    get 'Fetch a fit/gap report' do
      tags 'Fit/gap'
      security [bearer_auth: []]
      produces 'application/json'

      let(:portfolio) { create_portfolio(session).first }
      let(:vacancy) { create_vacancy(org) }
      let(:id) { portfolio.id }
      let(:vacancy_id) { vacancy.id }

      response '200', 'report' do
        schema type: :object, required: %w[report], properties: { report: { '$ref' => '#/components/schemas/FitGapReport' } }
        before { build_report(portfolio, vacancy) }
        run_test!
      end

      response '404', 'report not generated yet' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
