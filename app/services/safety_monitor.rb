# frozen_string_literal: true

# ============================================================================
# COMPLIANCE WARNING - DO NOT MODIFY WITHOUT AUTHORIZATION
# ============================================================================
# This file is subject to regulatory compliance requirements.
# See COMPLIANCE.md Section 4 for mandatory review process.
#
# Modifications to this file require:
# 1. Safety reviewer sign-off
# 2. All 80+ safety tests passing (spec/services/safety_monitor_spec.rb)
# 3. Documentation update in COMPLIANCE.md
# 4. Staged rollout with monitoring
#
# This system uses DETERMINISTIC pattern matching, NOT AI.
# Adding AI/ML would trigger EU AI Act High-Risk classification.
# ============================================================================

# SafetyMonitor is the core safety detection service for Six Steps.
# It uses DETERMINISTIC pattern matching (not AI) to detect crisis language
# and calculate depth scores. This ensures the safety system is:
# - Testable and auditable
# - Predictable in behaviour
# - Free from AI hallucination risks
class SafetyMonitor
  # Crisis patterns that require immediate intervention
  # These are deterministic regex patterns, not AI-based detection
  CRISIS_PATTERNS = {
    immediate_risk: [
      /\b(suicide|suicidal)\b/i,
      /\b(kill myself|kill my self)\b/i,
      /\b(end it all|end my life)\b/i,
      /\b(don't want to live|dont want to live)\b/i,
      /\b(want to die|wanna die)\b/i,
      /\b(rather be dead|better off dead)\b/i,
      /\b(hurt myself|harm myself)\b/i,
      /\b(self[- ]?harm|cut myself|cutting myself)\b/i,
      /\b(overdose|take pills|taken pills|stockpiling pills|stockpiled pills)\b/i,
      /\b(plan to (die|end|kill))\b/i,
      /\b(method to (die|end|kill))\b/i
    ],
    elevated_risk: [
      /\b(no point|no hope|hopeless)\b/i,
      /\b(worthless|i('?m| am) (a )?burden)\b/i,
      /\b(can't go on|cant go on|cannot go on)\b/i,
      /\b(can't cope|cant cope|cannot cope)\b/i,
      /\b(can't take it|cant take it)\b/i,
      /\b(give up|giving up|given up) (on (life|everything|myself))\b/i,
      /\b(no reason to (live|keep going|continue))\b/i,
      /\b(wish i (was|were) dead)\b/i,
      /\b(wish i (wasn't|weren't) (here|alive|born))\b/i
    ]
  }.freeze

  # Words indicating high emotional intensity
  EMOTIONAL_INTENSITY_WORDS = %w[
    terrified terrifying panic panicking panicked
    overwhelming overwhelmed unbearable devastating devastated
    shattered destroyed broken crushed crushing
    agonizing agony torment tormented despair despairing
    hopeless helpless powerless trapped suffocating
  ].freeze

  # Absolutist language that may indicate rigid thinking
  ABSOLUTIST_WORDS = %w[
    never always nothing everything nobody everyone
    impossible completely totally entirely absolutely
    forever none all worst
  ].freeze

  # Words indicating hopelessness (lower weight than crisis patterns)
  HOPELESSNESS_WORDS = %w[
    pointless meaningless useless empty hollow
    numb disconnected alone isolated abandoned
    failed failure failing worthless
  ].freeze

  # Depth score thresholds
  THRESHOLDS = {
    green: 0.0..0.3,
    amber: 0.3..0.5,
    orange: 0.5..0.7,
    red: 0.7..0.9,
    crisis: 0.9..1.0
  }.freeze

  attr_reader :session, :depth_score, :triggers, :intervention_type

  def initialize(session)
    @session = session
    @depth_score = session.current_depth_score
    @triggers = []
    @intervention_type = nil
  end

  # Main assessment method - analyzes user input and determines response
  def assess(user_input)
    @depth_score = calculate_depth_score(user_input)
    determine_intervention
    self
  end

  # Check if this is a crisis-level situation requiring immediate intervention
  def crisis?
    @intervention_type == :crisis
  end

  # Check if any intervention is needed
  def needs_intervention?
    @intervention_type.present?
  end

  # Check if depth score is at amber level or higher
  def amber_or_higher?
    @depth_score >= 0.3
  end

  # Get the current safety level as a symbol
  def safety_level
    case @depth_score
    when THRESHOLDS[:crisis] then :crisis
    when THRESHOLDS[:red] then :red
    when THRESHOLDS[:orange] then :orange
    when THRESHOLDS[:amber] then :amber
    else :green
    end
  end

  # Get anonymized trigger data for audit logging (no user content stored)
  def anonymized_triggers
    @triggers.map do |trigger|
      {
        type: trigger[:type],
        level: trigger[:level],
        pattern_category: trigger[:pattern_category]
      }
    end
  end

  private

  def calculate_depth_score(input)
    # Start with a BASE score, not the accumulated session score
    # The session score should only be used for display/history, not for compounding
    base_score = 0.0
    normalized_input = input.to_s.downcase

    # Crisis patterns - immediate escalation to maximum
    if matches_crisis_pattern?(normalized_input, :immediate_risk)
      return 1.0
    end

    # Elevated risk patterns
    if matches_crisis_pattern?(normalized_input, :elevated_risk)
      base_score += 0.5
      @triggers << { type: :elevated_risk, level: :high, pattern_category: "elevated_risk" }
    end

    # Emotional intensity words
    emotional_count = count_word_matches(normalized_input, EMOTIONAL_INTENSITY_WORDS)
    if emotional_count > 0
      intensity_contribution = (emotional_count * 0.1).clamp(0, 0.3)
      base_score += intensity_contribution
      @triggers << { type: :emotional_intensity, level: :medium, pattern_category: "emotional" } if emotional_count >= 2
    end

    # Absolutist language
    absolutist_count = count_word_matches(normalized_input, ABSOLUTIST_WORDS)
    if absolutist_count > 0
      absolutist_contribution = (absolutist_count * 0.05).clamp(0, 0.2)
      base_score += absolutist_contribution
      @triggers << { type: :absolutist_language, level: :low, pattern_category: "absolutist" } if absolutist_count >= 3
    end

    # Hopelessness words
    hopelessness_count = count_word_matches(normalized_input, HOPELESSNESS_WORDS)
    if hopelessness_count > 0
      hopelessness_contribution = (hopelessness_count * 0.1).clamp(0, 0.3)
      base_score += hopelessness_contribution
      @triggers << { type: :hopelessness, level: :medium, pattern_category: "hopelessness" } if hopelessness_count >= 2
    end

    # Session context adds a small baseline (max 0.25 from session factors)
    # This provides context awareness without runaway accumulation
    session_factor = 0.0
    session_factor += (@session.iteration_count * 0.02).clamp(0, 0.12)  # Max 0.12 at 6 iterations
    session_factor += (@session.duration_minutes / 150.0).clamp(0, 0.08)  # Max 0.08 at 12+ mins
    session_factor += (@session.grounding_insertions_count * 0.03).clamp(0, 0.05)  # Max 0.05

    # Combine: content-based score + session context
    # Previous depth score influences as a smaller "memory" factor
    memory_factor = (@session.current_depth_score * 0.2).clamp(0, 0.15)

    final_score = base_score + session_factor + memory_factor
    final_score.clamp(0.0, 1.0)
  end

  def matches_crisis_pattern?(input, level)
    CRISIS_PATTERNS[level].any? do |pattern|
      if input.match?(pattern)
        @triggers << {
          type: :crisis,
          level: level,
          pattern_category: level.to_s
        }
        true
      else
        false
      end
    end
  end

  def count_word_matches(input, word_list)
    word_list.count { |word| input.include?(word) }
  end

  def determine_intervention
    @intervention_type = case @depth_score
    when 0.9..1.0 then :crisis
    when 0.7...0.9 then :integration_needed
    when 0.5...0.7 then :pause_suggested
    when 0.3...0.5 then :grounding_needed
    else nil
    end
  end
end
