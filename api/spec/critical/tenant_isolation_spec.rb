# frozen_string_literal: true

require 'rails_helper'

# Protects: one customer must never read or change another customer's candidates (audit R-01, R-02).
# Does NOT cover: WebSocket endpoints (needs a socket-level test), database row-level security.
RSpec.describe 'Tenant isolation', :critical, type: :request do
  let!(:org_a) { create_org(scheme: 'org-a') }
  let!(:org_b) { create_org(scheme: 'org-b') }
  let(:headers_a) { { 'Authorization' => bearer(org_a), 'Content-Type' => 'application/json' } }

  # Everything below belongs to org B; the caller is an admin of org A.
  let(:session_b)   { create_interview(create_assessment(org_b), status: 'active') }
  let(:portfolio_b) { create_portfolio(session_b).first }
  let(:skill_b)     { create_portfolio(session_b).last }
  let(:vacancy_a)   { create_vacancy(org_a) }

  describe 'portfolio routes addressed by their own id' do
    before { portfolio_b } # materialise org B's data

    it 'does not export a portfolio of another tenant' do
      get "/api/v1/portfolios/#{portfolio_b.id}/export", params: { format: 'json' }, headers: headers_a
      expect(response).to have_http_status(:not_found)
    end

    it 'does not run a fit/gap on a portfolio of another tenant' do
      post "/api/v1/portfolios/#{portfolio_b.id}/fitgap",
           params: { fitgap: { vacancy_id: vacancy_a.id } }.to_json, headers: headers_a
      expect(response).to have_http_status(:not_found)
      expect(FitGapGeneratorWorker.jobs).to be_empty
    end

    it 'does not regenerate a fit/gap of another tenant' do
      post "/api/v1/portfolios/#{portfolio_b.id}/regenerate_fitgap",
           params: { vacancy_id: vacancy_a.id }.to_json, headers: headers_a
      expect(response).to have_http_status(:not_found)
      expect(FitGapGeneratorWorker.jobs).to be_empty
    end

    it 'does not show a fit/gap report of another tenant' do
      vacancy_b = create_vacancy(org_b)
      FitGapReport.create!(portfolio: portfolio_b, vacancy: vacancy_b, skill_comparisons: [{ skill_label: 'x', result: 'match' }])
      get "/api/v1/portfolios/#{portfolio_b.id}/fitgap/#{vacancy_b.id}", headers: headers_a
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'rating overrides' do
    it 'does not let another tenant change a rating' do
      skill = skill_b
      post "/api/v1/portfolio_skills/#{skill.id}/override",
           params: { override: { override_level: 1, assessor_notes: 'tampered' } }.to_json, headers: headers_a

      expect(response).to have_http_status(:not_found)
      expect(AssessorOverride.where(portfolio_skill_id: skill.id)).to be_empty
    end
  end

  describe 'login' do
    before { create_user(email: 'admin@example.test', password: 'Passw0rd!') }

    it 'does not issue a token for a tenant the client asked for' do
      post '/api/v1/auth/login',
           params: { email: 'admin@example.test', password: 'Passw0rd!' }.to_json,
           headers: { 'Content-Type' => 'application/json', 'X-Tenant-Scheme' => org_b.scheme }

      expect(response).to have_http_status(:ok)
      expect(token_scheme(json['token'])).not_to eq(org_b.scheme)
    end
  end

  describe 'sanity: the caller still sees its own tenant (regression guard)' do
    it 'lists only its own assessments' do
      create_assessment(org_a, name: 'Mine')
      create_assessment(org_b, name: 'Theirs')
      get '/api/v1/assessments', headers: headers_a
      expect(json['assessments'].map { |a| a['name'] }).to eq(['Mine'])
    end
  end
end
