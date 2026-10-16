# frozen_string_literal: true

module Portfolios
  # N10: Generates a structured skill portfolio from the full transcript
  # and final coverage map using Gemini Pro.
  # Runs post-session as a background job.
  class Generator
    class InvalidOutput < StandardError; end
    class InsufficientTranscript < StandardError; end

    MAX_DISCOVERED = 10

    def initialize(session:, gemini_client: nil)
      @session = session
      @gemini_client = gemini_client || Gemini::HttpClient.new(
        model:   ENV.fetch('GEMINI_PRO_MODEL', 'gemini-2.0-pro-001'),
        timeout: 180  # up to 3 minutes for large transcripts
      )
    end

    # Returns the Portfolio record with skills populated.
    #
    # A rating is derived from the interview and from our own records, never from LLM text alone (SPEC-002):
    #   - the transcript must be complete before anything is rated,
    #   - the LLM answer is validated in full before anything is written,
    #   - identity and confidence come from the configured skills and the coverage map,
    #   - the skills are replaced in one transaction: all of them, or none.
    def call
      portfolio = @session.portfolio || @session.create_portfolio!(
        candidate_id:      @session.candidate_id,
        generation_status: 'pending'
      )

      portfolio.update!(generation_status: 'generating', generation_error: nil)

      verify_transcript!
      response   = @gemini_client.generate_content(build_prompt, temperature: 0.2)
      skill_rows = validated_skills(response)

      PortfolioSkill.transaction do
        portfolio.portfolio_skills.destroy_all
        skill_rows.each { |attrs| portfolio.portfolio_skills.create!(attrs) }
      end
      portfolio.update!(generation_status: 'complete', generated_at: Time.current)

      Rails.logger.info("[N10] Portfolio generated for session #{@session.id}")
      portfolio
    rescue => e
      portfolio&.update!(generation_status: 'failed', generation_error: e.message)
      Rails.logger.error("[N10] Portfolio generation failed for session #{@session.id}: #{e.class} #{e.message}")
      raise
    end

    private

    def build_prompt
      assessment       = @session.assessment
      configured_skills = assessment.assessment_skills.order(:display_order)
      coverage_maps     = @session.coverage_maps.order(:id)
      turns             = @session.transcript_turns.ordered

      skills_text = configured_skills.map { |s| skill_definition_block(s) }.join("\n\n")

      coverage_json = {
        skills:     coverage_maps.reject(&:is_discovered).map { |m| coverage_json(m) },
        discovered: coverage_maps.select(&:is_discovered).map { |m| coverage_json(m) }
      }.to_json

      transcript_text = turns.map { |t| "[#{t.speaker.upcase}]: #{t.text}" }.join("\n")

      <<~PROMPT
        You are evaluating a completed skills assessment interview to produce a structured skill portfolio.

        ROLE BEING ASSESSED: #{assessment.name}

        SKILL DEFINITIONS AND BEHAVIORAL ANCHORS:
        #{skills_text}

        UNIVERSAL L1-L5 ANCHORS (use for discovered skills):
        L1 — Executes with explicit guidance and close review. Understands conceptually but cannot apply independently.
        L2 — Executes independently on routine scope. Uses known patterns. Handles common cases but not edge cases.
        L3 — Executes complex, ambiguous scope. Makes tradeoffs. Handles edge cases. Can teach L1-L2.
        L4 — Defines standards and creates reusable systems. Resolves systemic problems. Cross-team impact.
        L5 — Org-level authority. Shapes how the skill is practiced. Rare.

        FINAL COVERAGE MAP:
        #{coverage_json}

        FULL INTERVIEW TRANSCRIPT:
        #{transcript_text}

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        TASK
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        For EACH skill in the coverage map (both configured and discovered):

        1. FIND THE EVIDENCE
           Read all transcript turns where this skill was discussed.
           Identify the 2-3 most revealing quotes from the CANDIDATE (not the AI).
           A quote is revealing if it shows HOW they think, not just WHAT they know.

        2. ASSIGN A LEVEL
           Compare the candidate's actual behavior to the L1-L5 anchors.
           Assign the highest level where you see CONSISTENT evidence, not just one strong moment.
           If evidence is mixed (mostly L2 with one L3 moment), assign L2.

        3. WRITE THE COMPETENCY SUMMARY
           2-3 sentences. Focus on patterns, not individual answers.
           What does this person reliably do at this skill? What's the ceiling? What's missing?

        Use the skill id and label EXACTLY as written in the definitions above. Do not rename or re-case them.
        Confidence is computed by the system from the coverage map; do not output it.

        OUTPUT (JSON only, no prose):
        {
          "configured_skills": [
            {
              "skill_id": "<id exactly as in the skill definitions>",
              "skill_label": "<label exactly as in the skill definitions>",
              "level": 3,
              "evidence": ["quote 1", "quote 2", "quote 3"],
              "competency_summary": "2-3 sentence summary"
            }
          ],
          "discovered_skills": [
            {
              "skill_label": "Micro-frontend Architecture",
              "level": 2,
              "evidence": ["quote 1"],
              "competency_summary": "2-3 sentence summary"
            }
          ]
        }
      PROMPT
    end

    def skill_definition_block(skill)
      lines = ["━━━━━━━━━━━━━━━"]
      lines << "SKILL: #{skill.skill_label} (#{skill.skill_id || 'custom'})"
      lines << "SCOPE: #{skill.scope_include}" if skill.scope_include.present?
      lines << ""
      lines << "L1 — #{skill.l1_anchor}"
      lines << "L2 — #{skill.l2_anchor}"
      lines << "L3 — #{skill.l3_anchor}"
      lines << "L4 — #{skill.l4_anchor}"
      lines << "L5 — #{skill.l5_anchor}"
      lines.join("\n")
    end

    def coverage_json(map)
      {
        id:          map.skill_id || map.skill_label.downcase.gsub(/\s+/, '-'),
        label:       map.skill_label,
        state:       map.state,
        probe_count: map.probe_count,
        is_discovered: map.is_discovered
      }
    end

    # ---- transcript ------------------------------------------------------------------------------

    def verify_transcript!
      turns = @session.transcript_turns.order(:turn_number).pluck(:turn_number)
      raise InsufficientTranscript, 'transcript is empty: nothing to rate' if turns.empty?

      unless @session.transcript_turns.where(speaker: 'candidate').exists?
        raise InsufficientTranscript, 'transcript has no candidate turns: nothing to rate'
      end

      missing = (1..turns.max).to_a - turns
      return if missing.empty?

      raise InsufficientTranscript, "transcript incomplete: missing turn(s) #{missing.first(10).join(', ')}"
    end

    # ---- LLM answer -> rows we are willing to store ----------------------------------------------

    def validated_skills(response)
      data = response.is_a?(Hash) ? response : JSON.parse(response.to_s)
      raise InvalidOutput, 'LLM output is not a JSON object' unless data.is_a?(Hash)

      rows = configured_rows(Array(data['configured_skills']))
      rows + discovered_rows(Array(data['discovered_skills']), rows)
    rescue JSON::ParserError => e
      raise InvalidOutput, "LLM output is not valid JSON: #{e.message[0, 120]}"
    end

    def configured_rows(entries)
      configured = @session.assessment.assessment_skills.order(:display_order).to_a
      matched    = {}

      entries.each do |entry|
        skill = match_configured(configured, entry) or
          raise InvalidOutput, "LLM rated a skill that is not configured: #{entry['skill_label'].inspect}"
        raise InvalidOutput, "LLM rated #{skill.skill_label.inspect} twice" if matched.key?(skill.id)

        matched[skill.id] = row_for(entry, skill_id: skill.skill_id, label: skill.skill_label, discovered: false)
      end

      omitted = configured.reject { |s| matched.key?(s.id) }
      raise InvalidOutput, "LLM omitted configured skill(s): #{omitted.map(&:skill_label).join(', ')}" if omitted.any?

      configured.map { |s| matched[s.id] }
    end

    def discovered_rows(entries, configured_rows)
      taken = configured_rows.map { |r| norm_label(r[:skill_label]) }
      rows  = []

      entries.each do |entry|
        key = norm_label(entry['skill_label'])
        raise InvalidOutput, 'LLM returned a discovered skill without a label' if key.empty?
        next if taken.include?(key)

        taken << key
        rows << row_for(entry, skill_id: nil, label: entry['skill_label'].to_s.strip, discovered: true)
      end

      raise InvalidOutput, "LLM returned more than #{MAX_DISCOVERED} discovered skills" if rows.size > MAX_DISCOVERED

      rows
    end

    def row_for(entry, skill_id:, label:, discovered:)
      {
        skill_id:           skill_id,
        skill_label:        label,
        is_discovered:      discovered,
        ai_level:           level_from(entry['level'], label),
        ai_confidence:      confidence_from_coverage(skill_id, label, discovered),
        evidence:           evidence_from(entry['evidence'], label),
        competency_summary: summary_from(entry['competency_summary'], label)
      }
    end

    def match_configured(configured, entry)
      id = norm_id(entry['skill_id'])
      configured.find { |s| s.skill_id.present? && id.present? && norm_id(s.skill_id) == id } ||
        configured.find { |s| norm_label(s.skill_label) == norm_label(entry['skill_label']) }
    end

    # The level is an integer 1..5. Anything else fails the generation: it is never clamped or defaulted.
    def level_from(raw, label)
      value = case raw
              when Integer then raw
              when Float   then raw == raw.to_i ? raw.to_i : nil
              when String  then raw[/\A\s*L?([1-5])\s*\z/i, 1]&.to_i
              end
      return value if value&.between?(1, 5)

      raise InvalidOutput, "invalid level #{raw.inspect} for #{label.inspect} (expected an integer 1..5)"
    end

    def evidence_from(raw, label)
      quotes = Array(raw).map { |q| q.to_s.strip }.reject(&:empty?).first(3)
      raise InvalidOutput, "no evidence quoted for #{label.inspect}" if quotes.empty?

      quotes
    end

    def summary_from(raw, label)
      text = raw.to_s.strip
      raise InvalidOutput, "no competency summary for #{label.inspect}" if text.empty?

      text
    end

    # PRD 01: high = covered and probe_count >= 3; medium = probe_count 2 or partial; low = probe_count <= 1 or
    # initiated. Computed here from the coverage map; the LLM's opinion of its own confidence is not used.
    def confidence_from_coverage(skill_id, label, discovered)
      row = coverage_row(skill_id, label, discovered)
      return 'low' unless row
      return 'high' if row.state == 'covered' && row.probe_count >= 3
      return 'low' if row.probe_count <= 1 || %w[not_yet initiated].include?(row.state)

      'medium'
    end

    def coverage_row(skill_id, label, discovered)
      @coverage_rows ||= @session.coverage_maps.to_a
      @coverage_rows.find do |m|
        next false unless m.is_discovered == discovered

        (skill_id.present? && m.skill_id.present? && norm_id(m.skill_id) == norm_id(skill_id)) ||
          norm_label(m.skill_label) == norm_label(label)
      end
    end

    def norm_id(value)
      value.to_s.strip.upcase
    end

    def norm_label(value)
      value.to_s.downcase.gsub(/\s+/, ' ').strip
    end
  end
end
