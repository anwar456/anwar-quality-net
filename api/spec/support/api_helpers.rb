# frozen_string_literal: true

# Small, explicit builders. Deliberately not factory_bot: every record a spec depends on is visible in the spec.
module ApiHelpers
  ANCHORS = {
    l1_anchor: 'L1 anchor', l2_anchor: 'L2 anchor', l3_anchor: 'L3 anchor',
    l4_anchor: 'L4 anchor', l5_anchor: 'L5 anchor'
  }.freeze

  def create_org(scheme: 'org-a')
    Organization.find_by(scheme: scheme) ||
      Organization.create!(name: scheme.tr('-', ' ').titleize, scheme: scheme, identifier: scheme, host: "#{scheme}.test")
  end

  def token_for(org, role: 'admin', user_id: 1)
    JsonWebToken.encode({ user_id: user_id, role: role, scheme: org.scheme })
  end

  def bearer(org, **opts)
    "Bearer #{token_for(org, **opts)}"
  end

  # org: the organization the user belongs to; nil creates an unassigned (legacy) user.
  def create_user(email: 'admin@example.test', password: 'Passw0rd!', role: 'admin', org: nil)
    User.create!(email: email, password: password, role: role, tenant_id: org&.id)
  end

  def create_taxonomy(skill_id: 'SK-TEST-001', label: 'Test Skill')
    SkillTaxonomy.create!(skill_id: skill_id, skill_label: label, category: 'engineering', **ANCHORS)
  end

  def create_assessment(org, name: 'Backend Engineer', time_limit_min: 30, skills: [['SK-TEST-001', 'Test Skill']])
    Assessment.create!(
      tenant_id: org.id, created_by: 1, name: name, time_limit_min: time_limit_min, language: 'en',
      assessment_skills_attributes: skills.each_with_index.map do |(skill_id, label), i|
        { skill_id: skill_id, skill_label: label, is_custom: skill_id.nil?, expected_level: 3, display_order: i, **ANCHORS }
      end
    )
  end

  def create_interview(assessment, status: 'pending', candidate_name: 'Ada Candidate')
    Session.create!(tenant_id: assessment.tenant_id, assessment: assessment, candidate_name: candidate_name, status: status)
  end

  def create_vacancy(org, role_title: 'Senior Backend Engineer', skills: [['SK-TEST-001', 'Test Skill', 3]])
    Vacancy.create!(
      tenant_id: org.id, created_by: 1, role_title: role_title,
      vacancy_skills_attributes: skills.map { |id, label, level| { skill_id: id, skill_label: label, expected_level: level } }
    )
  end

  # A finished interview with a generated portfolio, as the workers would leave it.
  def create_portfolio(session, status: 'complete', level: 3, label: 'Test Skill', skill_id: 'SK-TEST-001')
    session.update!(status: 'ended', end_reason: 'all_covered', started_at: 40.minutes.ago, ended_at: 1.minute.ago, duration_seconds: 2340)
    portfolio = Portfolio.create!(session: session, candidate_id: session.candidate_id, generation_status: status,
                                  generated_at: (Time.current if status == 'complete'))
    skill = portfolio.portfolio_skills.create!(
      skill_id: skill_id, skill_label: label, is_discovered: false, ai_level: level, ai_confidence: 'high',
      evidence: ['"a quote from the candidate"'], competency_summary: 'Reliable at this skill.'
    )
    [portfolio, skill]
  end

  def create_coverage(session, skill_id:, label:, state:, probe_count:, discovered: false)
    session.coverage_maps.create!(skill_id: skill_id, skill_label: label, state: state, probe_count: probe_count,
                                  is_discovered: discovered)
  end

  # Alternating ai/candidate turns numbered 1..count (or the given numbers, to build a transcript with a gap).
  def create_turns(session, count: nil, numbers: nil)
    (numbers || (1..count).to_a).each do |n|
      session.transcript_turns.create!(turn_number: n, speaker: n.odd? ? 'ai' : 'candidate', text: "turn #{n} text")
    end
  end

  def token_scheme(token)
    JsonWebToken.decode(token)[:scheme]
  end

  def json
    JSON.parse(response.body)
  end
end
