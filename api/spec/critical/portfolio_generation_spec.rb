# frozen_string_literal: true

require 'rails_helper'

# Protects: the rating a hiring manager reads is derived from the interview and from our own records,
# never from whatever text the LLM returned (audit R-04, R-05, R-11).
# Does NOT cover: whether the LLM's judgement is good (that is a model-evaluation problem, not a code check).
RSpec.describe Portfolios::Generator, :critical do
  let!(:org) { create_org }
  let(:assessment) do
    create_assessment(org, skills: [['SK-TEST-001', 'Test Skill'], ['SK-TEST-002', 'Other Skill']])
  end
  let(:session) do
    create_interview(assessment, status: 'ended').tap do |s|
      create_turns(s, count: 6)
      create_coverage(s, skill_id: 'SK-TEST-001', label: 'Test Skill', state: 'covered', probe_count: 4)
      create_coverage(s, skill_id: 'SK-TEST-002', label: 'Other Skill', state: 'partial', probe_count: 2)
    end
  end

  def skill_payload(overrides = {})
    { 'skill_id' => 'SK-TEST-001', 'skill_label' => 'Test Skill', 'level' => 3, 'confidence' => 'high',
      'evidence' => ['"quote"'], 'competency_summary' => 'Summary.' }.merge(overrides)
  end

  def generate(configured, discovered: [])
    llm = FakeLlm.new('configured_skills' => configured, 'discovered_skills' => discovered)
    described_class.new(session: session, gemini_client: llm).call
  end

  let(:portfolio) { session.reload.portfolio }

  describe 'identity of a rated skill' do
    it 'is the configured skill, even if the LLM echoes a different id or label' do
      generate([
        skill_payload('skill_id' => 'sk-test-001', 'skill_label' => 'Test Skill (core)'),
        skill_payload('skill_id' => 'SK-TEST-002', 'skill_label' => 'Other Skill', 'level' => 2, 'confidence' => 'medium')
      ])

      stored = portfolio.portfolio_skills.where(is_discovered: false).order(:id).pluck(:skill_id, :skill_label)
      expect(stored).to eq([['SK-TEST-001', 'Test Skill'], ['SK-TEST-002', 'Other Skill']])
    end
  end

  describe 'level' do
    it 'is rejected when the LLM omits it, instead of silently becoming L1' do
      expect { generate([skill_payload('level' => nil), skill_payload('skill_id' => 'SK-TEST-002', 'skill_label' => 'Other Skill')]) }
        .to raise_error(StandardError)

      expect(portfolio.generation_status).to eq('failed')
      expect(portfolio.portfolio_skills.count).to eq(0)
    end

    it 'is rejected when it is out of range, instead of being clamped' do
      expect { generate([skill_payload('level' => 9), skill_payload('skill_id' => 'SK-TEST-002', 'skill_label' => 'Other Skill')]) }
        .to raise_error(StandardError)

      expect(portfolio.portfolio_skills.count).to eq(0)
    end
  end

  describe 'confidence' do
    it 'is computed from the coverage map (PRD: high = covered and probe_count >= 3), not taken from the LLM' do
      generate([
        skill_payload('confidence' => 'high'),
        skill_payload('skill_id' => 'SK-TEST-002', 'skill_label' => 'Other Skill', 'level' => 2, 'confidence' => 'high')
      ])

      by_id = portfolio.portfolio_skills.index_by(&:skill_id)
      expect(by_id['SK-TEST-001'].ai_confidence).to eq('high')   # covered, 4 probes
      expect(by_id['SK-TEST-002'].ai_confidence).to eq('medium') # partial, 2 probes - the LLM said 'high'
    end
  end

  describe 'atomicity' do
    it 'persists nothing when any skill in the payload is invalid' do
      expect do
        generate([skill_payload, skill_payload('skill_id' => 'SK-TEST-002', 'skill_label' => 'Other Skill', 'competency_summary' => '')])
      end.to raise_error(StandardError)

      expect(portfolio.generation_status).to eq('failed')
      expect(portfolio.portfolio_skills.count).to eq(0)
    end
  end

  describe 'evidence of the interview' do
    it 'refuses to rate an interview that has no transcript' do
      session.transcript_turns.delete_all

      expect { generate([skill_payload]) }.to raise_error(StandardError)
      expect(portfolio.generation_status).to eq('failed')
      expect(portfolio.portfolio_skills.count).to eq(0)
    end

    it 'refuses to rate a transcript with missing turns' do
      session.transcript_turns.where(turn_number: 3).delete_all

      expect { generate([skill_payload]) }.to raise_error(StandardError, /transcript/i)
      expect(portfolio.portfolio_skills.count).to eq(0)
    end
  end

  describe 'what the LLM must give us' do
    it 'refuses to rate a transcript that contains only interviewer turns' do
      session.transcript_turns.where(speaker: 'candidate').delete_all

      expect { generate([skill_payload]) }.to raise_error(StandardError, /candidate/i)
      expect(portfolio.portfolio_skills.count).to eq(0)
    end

    it 'fails when a configured skill is left out, instead of silently dropping it' do
      expect { generate([skill_payload]) }.to raise_error(StandardError, /omitted/i)
      expect(portfolio.portfolio_skills.count).to eq(0)
    end

    it 'fails when it rates a skill we never configured' do
      expect do
        generate([skill_payload, skill_payload('skill_id' => 'SK-TEST-002', 'skill_label' => 'Other Skill'),
                  skill_payload('skill_id' => 'SK-NOPE', 'skill_label' => 'Invented Skill')])
      end.to raise_error(StandardError, /not configured/i)
    end

    it 'fails when a rating quotes no evidence' do
      expect { generate([skill_payload('evidence' => []), skill_payload('skill_id' => 'SK-TEST-002', 'skill_label' => 'Other Skill')]) }
        .to raise_error(StandardError, /evidence/i)
    end

    it 'accepts the level written as "L3" or "3" but nothing else' do
      generate([skill_payload('level' => 'L3'), skill_payload('skill_id' => 'SK-TEST-002', 'skill_label' => 'Other Skill', 'level' => '2')])
      expect(portfolio.portfolio_skills.order(:id).pluck(:ai_level)).to eq([3, 2])
    end
  end

  describe 'regression guard: the happy path still works' do
    it 'stores a complete portfolio for a complete interview' do
      generate([
        skill_payload,
        skill_payload('skill_id' => 'SK-TEST-002', 'skill_label' => 'Other Skill', 'level' => 2, 'confidence' => 'medium')
      ], discovered: [{ 'skill_label' => 'Micro-frontends', 'level' => 2, 'confidence' => 'low',
                        'evidence' => ['"q"'], 'competency_summary' => 'Brief.' }])

      expect(portfolio.generation_status).to eq('complete')
      expect(portfolio.portfolio_skills.where(is_discovered: true).pluck(:skill_label)).to eq(['Micro-frontends'])
    end
  end
end
