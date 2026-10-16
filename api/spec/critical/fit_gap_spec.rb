# frozen_string_literal: true

require 'rails_helper'

# Protects: the fit/gap table a hiring manager decides from (audit R-04).
# Does NOT cover: the wording of the narrative (LLM text), PDF rendering.
RSpec.describe FitGap::Engine, :critical do
  let!(:org) { create_org }
  let(:session) { create_interview(create_assessment(org), status: 'ended') }
  let(:portfolio) { Portfolio.create!(session: session, generation_status: 'complete', generated_at: Time.current) }
  let(:llm) { FakeLlm.new('culture_narrative' => 'c', 'overall_narrative' => 'o') }

  def add_skill(skill_id:, label:, level:, confidence: 'high')
    portfolio.portfolio_skills.create!(skill_id: skill_id, skill_label: label, is_discovered: false, ai_level: level,
                                       ai_confidence: confidence, evidence: [], competency_summary: 's')
  end

  def comparison(report, label)
    report.skill_comparisons.find { |c| c['skill_label'] == label }
  end

  def run(vacancy)
    described_class.new(portfolio: portfolio, vacancy: vacancy, gemini_client: llm).call
  end

  it 'matches a rated skill to the vacancy requirement even if the stored id differs only in case or spacing' do
    add_skill(skill_id: 'sk-test-001 ', label: 'Test Skill (core)', level: 3)
    report = run(create_vacancy(org, skills: [['SK-TEST-001', 'Test Skill', 3]]))

    expect(comparison(report, 'Test Skill')).to include('result' => 'match', 'candidate_level' => 3)
  end

  it 'reports the required level under the key the web reads' do
    add_skill(skill_id: 'SK-TEST-001', label: 'Test Skill', level: 3)
    report = run(create_vacancy(org, skills: [['SK-TEST-001', 'Test Skill', 3]]))

    expect(comparison(report, 'Test Skill')).to include('expected_level' => 3)
  end

  describe 'regression guards' do
    it 'classifies gap, match and exceed from the level difference' do
      add_skill(skill_id: 'SK-A', label: 'A', level: 2)
      add_skill(skill_id: 'SK-B', label: 'B', level: 3)
      add_skill(skill_id: 'SK-C', label: 'C', level: 4)
      report = run(create_vacancy(org, skills: [['SK-A', 'A', 3], ['SK-B', 'B', 3], ['SK-C', 'C', 3]]))

      expect(report.skill_comparisons.map { |c| [c['skill_label'], c['result'], c['delta']] })
        .to eq([['A', 'gap', -1], ['B', 'match', 0], ['C', 'exceed', 1]])
    end

    it 'uses the assessor override instead of the AI level' do
      skill = add_skill(skill_id: 'SK-A', label: 'A', level: 2)
      skill.create_assessor_override!(ai_level: 2, override_level: 4, overridden_by: 1)
      report = run(create_vacancy(org, skills: [['SK-A', 'A', 3]]))

      expect(comparison(report, 'A')).to include('candidate_level' => 4, 'result' => 'exceed')
    end

    it 'says "not_assessed" for a requirement that was never rated, and does not invent a level' do
      add_skill(skill_id: 'SK-A', label: 'A', level: 3)
      report = run(create_vacancy(org, skills: [['SK-Z', 'Z', 3]]))

      expect(comparison(report, 'Z')).to include('result' => 'not_assessed', 'candidate_level' => nil)
    end
  end
end
