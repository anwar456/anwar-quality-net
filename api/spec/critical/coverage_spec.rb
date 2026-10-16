# frozen_string_literal: true

require 'rails_helper'

# Protects: "covered" means the analyzer saw enough evidence, because it decides when an interview ends and how
# confident a rating is (audit R-06). Does NOT cover: the quality of the analyzer's LLM judgement.
RSpec.describe 'Coverage rules', :critical do
  describe CoverageAnalyzerWorker do
    let!(:org) { create_org }
    let(:session) { create_interview(create_assessment(org), status: 'active') }

    before do
      allow_any_instance_of(Coverage::Analyzer).to receive(:call).and_return(skill_updates: [], discovered_skills: [])
    end

    it 'never promotes a partial skill to covered on probe count alone' do
      map = create_coverage(session, skill_id: 'SK-TEST-001', label: 'Test Skill', state: 'partial', probe_count: 5)
      create_turns(session, count: 4)

      described_class.new.perform(session.id, 4)

      expect(map.reload.state).to eq('partial')
    end
  end

  describe Coverage::StateEngine do
    it 'does not move past "initiated" before two probes (PRD hard rule)' do
      expect(described_class.resolve_state(current_state: 'initiated', proposed_state: 'covered', probe_count: 1))
        .to eq('initiated')
    end

    it 'walks one step at a time when the analyzer proposes a jump' do
      expect(described_class.resolve_state(current_state: 'not_yet', proposed_state: 'covered', probe_count: 3))
        .to eq('covered')
      expect(described_class.resolve_state(current_state: 'not_yet', proposed_state: 'covered', probe_count: 1))
        .to eq('initiated')
    end

    it 'never moves backwards' do
      expect(described_class.resolve_state(current_state: 'covered', proposed_state: 'partial', probe_count: 5))
        .to eq('covered')
    end
  end
end
