# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Sessions' do
  let!(:org) { create_org }
  let!(:other_org) { create_org(scheme: 'org-b') }
  let(:assessment) { create_assessment(org) }
  let(:Authorization) { bearer(org) }

  path '/api/v1/assessments/{assessment_id}/sessions' do
    parameter name: :assessment_id, in: :path, schema: { type: :integer }

    get 'List the sessions (candidates) of an assessment' do
      tags 'Sessions'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'sessions, newest first' do
        schema type: :object, required: %w[sessions],
               properties: { sessions: { type: :array, items: { '$ref' => '#/components/schemas/Session' } } }
        let(:assessment_id) { assessment.id }
        before { create_interview(assessment, candidate_name: 'First') }
        run_test! { expect(json['sessions'].size).to eq(1) }
      end

      response '404', 'assessment of another tenant' do
        schema '$ref' => '#/components/schemas/Error'
        let(:assessment_id) { create_assessment(other_org).id }
        run_test!
      end
    end

    post 'Invite a candidate (create a session)' do
      tags 'Sessions'
      description 'Returns the invite link. Known defect (audit R-07): the link is built from `APP_BASE_URL`, ' \
                  'which is the API host, while the interview page is served by the web app.'
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: { session: { type: :object, properties: { candidate_name: { type: :string }, candidate_id: { type: :integer } } } }
      }

      response '201', 'session created' do
        schema type: :object, required: %w[session invite_url],
               properties: { session: { '$ref' => '#/components/schemas/Session' }, invite_url: { type: :string } }
        let(:assessment_id) { assessment.id }
        let(:body) { { session: { candidate_name: 'Ahmad Rizky' } } }

        run_test! do
          expect(json['session']['status']).to eq('pending')
          expect(json['session']['tenant_id']).to eq(org.id)
          expect(json['invite_url']).to end_with("/interview/#{json['session']['invite_token']}")
        end
      end
    end
  end

  path '/api/v1/sessions/{id}' do
    parameter name: :id, in: :path, schema: { type: :integer }

    get 'Get a session' do
      tags 'Sessions'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'session with its assessment' do
        schema type: :object, required: %w[session],
               properties: {
                 session: {
                   allOf: [
                     { '$ref' => '#/components/schemas/Session' },
                     { type: :object, required: %w[assessment],
                       properties: { assessment: { type: :object, required: %w[id name time_limit_min],
                                                   properties: { id: { type: :integer }, name: { type: :string },
                                                                 time_limit_min: { type: :integer } } } } }
                   ]
                 }
               }
        let(:id) { create_interview(assessment).id }
        run_test!
      end

      response '404', 'session of another tenant' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { create_interview(create_assessment(other_org)).id }
        run_test!
      end
    end
  end

  path '/api/v1/sessions/{id}/end_session' do
    parameter name: :id, in: :path, schema: { type: :integer }

    post 'End a session as the assessor' do
      tags 'Sessions'
      description 'Marks the session ended, creates the portfolio and queues its generation. ' \
                  'Known gap (audit R-12): a live audio connection of the candidate is not closed.'
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: { session: { type: :object, properties: { reason: { type: :string, enum: %w[manual_assessor manual_candidate time_ceiling error all_covered] } } } }
      }

      response '200', 'ended' do
        schema type: :object, required: %w[session], properties: { session: { '$ref' => '#/components/schemas/Session' } }
        let(:id) { create_interview(assessment, status: 'active').id }
        let(:body) { { session: { reason: 'manual_assessor' } } }

        run_test! do
          expect(json['session']['status']).to eq('ended')
          expect(json['session']['end_reason']).to eq('manual_assessor')
          expect(Portfolio.where(session_id: id).count).to eq(1)
          expect(PortfolioGeneratorWorker.jobs.size).to eq(1)
        end
      end

      response '422', 'already ended' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { create_interview(assessment, status: 'ended').id }
        let(:body) { {} }
        run_test!
      end

      response '422', 'unknown reason' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { create_interview(assessment, status: 'active').id }
        let(:body) { { session: { reason: 'because' } } }
        run_test!
      end
    end
  end

  path '/api/v1/sessions/{id}/coverage' do
    parameter name: :id, in: :path, schema: { type: :integer }

    get 'Current coverage map of a session' do
      tags 'Sessions'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'configured and discovered skills' do
        schema type: :object, required: %w[skills discovered],
               properties: {
                 skills: { type: :array, items: { '$ref' => '#/components/schemas/CoverageSkill' } },
                 discovered: { type: :array, items: { '$ref' => '#/components/schemas/CoverageSkill' } },
                 updated_at: { type: :string, nullable: true }
               }
        let(:session) { create_interview(assessment, status: 'active') }
        let(:id) { session.id }
        before do
          session.coverage_maps.create!(skill_id: 'SK-TEST-001', skill_label: 'Test Skill', state: 'partial', probe_count: 2)
          session.coverage_maps.create!(skill_label: 'Micro-frontends', is_discovered: true, state: 'initiated', probe_count: 1)
        end

        run_test! do
          expect(json['skills'].size).to eq(1)
          expect(json['discovered'].size).to eq(1)
        end
      end
    end
  end

  path '/api/v1/sessions/{id}/transcript' do
    parameter name: :id, in: :path, schema: { type: :integer }

    get 'Transcript of a session' do
      tags 'Sessions'
      security [bearer_auth: []]
      produces 'application/json'
      parameter name: :from_turn, in: :query, required: false, schema: { type: :integer }

      response '200', 'turns in order' do
        schema type: :object, required: %w[turns total],
               properties: { turns: { type: :array, items: { '$ref' => '#/components/schemas/TranscriptTurn' } }, total: { type: :integer } }
        let(:session) { create_interview(assessment, status: 'active') }
        let(:id) { session.id }
        let(:from_turn) { 2 }
        before do
          session.transcript_turns.create!(turn_number: 1, speaker: 'ai', text: 'Hello')
          session.transcript_turns.create!(turn_number: 2, speaker: 'candidate', text: 'Hi')
          session.transcript_turns.create!(turn_number: 3, speaker: 'ai', text: 'Tell me more')
        end

        run_test! { expect(json['turns'].map { |t| t['turn_number'] }).to eq([2, 3]) }
      end
    end
  end

  path '/api/v1/sessions/{token}/candidate' do
    parameter name: :token, in: :path, schema: { type: :string }, description: 'Invite token (no JWT)'

    get 'Candidate: what the interview page needs to start' do
      tags 'Candidate'
      produces 'application/json'

      response '200', 'interview info' do
        schema type: :object, required: %w[session_id role_title time_limit_min session_status],
               properties: {
                 session_id: { type: :integer }, role_title: { type: :string },
                 time_limit_min: { type: :integer }, session_status: { type: :string }
               }
        let(:session) { create_interview(assessment) }
        let(:token) { session.invite_token }
        run_test! { expect(json['role_title']).to eq(assessment.name) }
      end

      response '404', 'unknown token' do
        schema '$ref' => '#/components/schemas/Error'
        let(:token) { 'nope' }
        run_test!
      end
    end
  end

  path '/api/v1/sessions/{token}/audio_complete' do
    parameter name: :token, in: :path, schema: { type: :string }, description: 'Invite token (no JWT)'

    post 'Candidate: the closing audio finished playing, end the session' do
      tags 'Candidate'
      description 'No authentication and no state check: it ends a session in any state with `end_reason=all_covered` ' \
                  'and queues portfolio generation (audit R-09).'
      produces 'application/json'

      response '200', 'ended (idempotent)' do
        schema type: :object, required: %w[ended message], properties: { ended: { type: :boolean }, message: { type: :string } }
        let(:session) { create_interview(assessment, status: 'active') }
        let(:token) { session.invite_token }

        run_test! do
          expect(session.reload.status).to eq('ended')
          expect(json['ended']).to be(true)
        end
      end

      response '404', 'unknown token' do
        schema '$ref' => '#/components/schemas/Error'
        let(:token) { 'nope' }
        run_test!
      end
    end
  end
end
