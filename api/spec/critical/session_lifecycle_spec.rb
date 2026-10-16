# frozen_string_literal: true

require 'rails_helper'

# Protects: what the screen says happened is what is stored (audit R-07, R-09, R-10).
# Does NOT cover: live audio / WebSocket behaviour (R-12) - that needs a socket-level integration test.
RSpec.describe 'Session lifecycle and data integrity', :critical, type: :request do
  let!(:org) { create_org }
  let(:assessment) { create_assessment(org) }
  let(:headers) { { 'Authorization' => bearer(org), 'Content-Type' => 'application/json' } }

  describe 'POST /sessions/:token/audio_complete (no login, invite token only)' do
    it 'does not end a session that never started' do
      session = create_interview(assessment, status: 'pending')

      post "/api/v1/sessions/#{session.invite_token}/audio_complete"

      expect(response).to have_http_status(:conflict)
      expect(session.reload.status).to eq('pending')
      expect(Portfolio.where(session_id: session.id)).to be_empty
    end

    it 'does not record "all_covered" while a configured skill is still open' do
      session = create_interview(assessment, status: 'active')
      create_coverage(session, skill_id: 'SK-TEST-001', label: 'Test Skill', state: 'partial', probe_count: 2)

      post "/api/v1/sessions/#{session.invite_token}/audio_complete"

      expect(response).to have_http_status(:conflict)
      expect(session.reload.status).to eq('active')
    end

    it 'ends the session once every configured skill is covered (regression guard)' do
      session = create_interview(assessment, status: 'active')
      create_coverage(session, skill_id: 'SK-TEST-001', label: 'Test Skill', state: 'covered', probe_count: 3)

      post "/api/v1/sessions/#{session.invite_token}/audio_complete"

      expect(response).to have_http_status(:ok)
      expect(session.reload).to have_attributes(status: 'ended', end_reason: 'all_covered')
    end

    it 'is idempotent for a session that has already ended (regression guard)' do
      session = create_interview(assessment, status: 'ended')
      post "/api/v1/sessions/#{session.invite_token}/audio_complete"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /assessments/:id' do
    it 'refuses, and says so, when the assessment already has candidates' do
      create_interview(assessment)

      delete "/api/v1/assessments/#{assessment.id}", headers: headers

      expect(response).to have_http_status(:conflict)
      expect(Assessment.unscoped.exists?(assessment.id)).to be(true)
    end
  end

  describe 'invite link' do
    around do |example|
      saved = ENV.to_h.slice('APP_BASE_URL', 'WEB_BASE_URL')
      ENV['APP_BASE_URL'] = 'https://api.example.test'
      ENV['WEB_BASE_URL'] = 'https://app.example.test'
      example.run
    ensure
      %w[APP_BASE_URL WEB_BASE_URL].each { |k| saved.key?(k) ? ENV[k] = saved[k] : ENV.delete(k) }
    end

    it 'points at the web app where the interview page lives, not at the API' do
      session = create_interview(assessment)
      expect(session.invite_url).to eq("https://app.example.test/interview/#{session.invite_token}")
    end
  end
end
