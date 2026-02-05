# frozen_string_literal: true

# ============================================================================
# COMPLIANCE TEST SUITE - SAFETY MONITOR
# ============================================================================
# These tests verify user safety and regulatory compliance requirements.
# See COMPLIANCE.md for full documentation.
#
# CRITICAL REQUIREMENTS:
# 1. System must be DETERMINISTIC (same input = same output, always)
# 2. System must NOT use AI/ML (EU AI Act High-Risk avoidance)
# 3. All crisis patterns must be detected with 100% reliability
# 4. False negatives on crisis detection are UNACCEPTABLE
#
# BEFORE MODIFYING THESE TESTS:
# - Any test removal requires safety reviewer sign-off
# - Any threshold change requires compliance review
# - Document changes in COMPLIANCE.md
# ============================================================================

require "rails_helper"

RSpec.describe SafetyMonitor do
  let(:user) { create(:user) }
  let(:session) { create(:journey_session, user: user, iteration_count: 0, current_depth_score: 0.0) }
  let(:monitor) { described_class.new(session) }

  describe "#assess" do
    context "with crisis-level immediate risk input" do
      # CRITICAL: These phrases MUST trigger crisis detection
      [
        "I want to kill myself",
        "I'm going to kill myself",
        "I want to kill my self",
        "I'm thinking about suicide",
        "I'm suicidal",
        "I want to end it all",
        "I want to end my life",
        "I don't want to live anymore",
        "I dont want to live",
        "I want to die",
        "I wanna die",
        "I'd rather be dead",
        "I'd be better off dead",
        "I'm better off dead",
        "I want to hurt myself",
        "I want to harm myself",
        "I've been cutting myself",
        "I'm thinking about cutting myself",
        "I'm going to self-harm",
        "I'm thinking about self harm",
        "I'm going to take an overdose",
        "I've been stockpiling pills",
        "I have a plan to die",
        "I have a plan to end it",
        "I know the method to kill myself"
      ].each do |phrase|
        it "detects crisis in: '#{phrase[0..40]}...'" do
          result = monitor.assess(phrase)

          expect(result.crisis?).to be(true),
            "CRITICAL FAILURE: Did not detect crisis in '#{phrase}' - score was #{result.depth_score}"
          expect(result.depth_score).to eq(1.0)
        end
      end
    end

    context "with elevated risk input" do
      [
        "There's no point anymore",
        "I feel so hopeless",
        "I'm completely hopeless",
        "I feel worthless",
        "I'm a burden to everyone",
        "I am a burden",
        "I can't go on like this",
        "I cant go on",
        "I cannot go on anymore",
        "I can't cope with this",
        "I cant cope",
        "I can't take it anymore",
        "I've given up on life",
        "I'm giving up on everything",
        "There's no reason to live",
        "No reason to keep going",
        "I wish I was dead",
        "I wish I were dead",
        "I wish I wasn't here",
        "I wish I weren't alive",
        "I wish I wasn't born"
      ].each do |phrase|
        it "detects elevated risk in: '#{phrase[0..40]}...'" do
          result = monitor.assess(phrase)

          expect(result.needs_intervention?).to be(true),
            "Should detect elevated risk in '#{phrase}' - score was #{result.depth_score}"
          expect(result.depth_score).to be >= 0.4
        end
      end
    end

    context "with emotional intensity words" do
      it "increases depth score for multiple intensity words" do
        result = monitor.assess("I feel terrified and overwhelmed, it's devastating")

        expect(result.depth_score).to be >= 0.3
        expect(result.amber_or_higher?).to be(true)
      end

      it "detects intensity in panic-related language" do
        result = monitor.assess("I'm panicking, everything is crushing me")

        expect(result.needs_intervention?).to be(true)
      end
    end

    context "with absolutist language" do
      it "increases score for absolutist words" do
        result = monitor.assess("I can never do anything right, everyone hates me, nothing works")

        expect(result.depth_score).to be > 0.1
      end

      it "accumulates score from multiple absolutist words" do
        result = monitor.assess("This always happens, everything is completely impossible, I'm totally alone forever")

        expect(result.depth_score).to be >= 0.2
      end
    end

    context "with safe/neutral input" do
      [
        "I notice a feeling of calm in my chest",
        "There's a warm sensation in my shoulders",
        "It's like a gentle wave",
        "I feel curious about this",
        "My health has been challenging but I'm coping",
        "Sometimes I feel sad about my diagnosis",
        "I've been thinking about my future",
        "I have good days and bad days",
        "My life is different now",
        "I'm learning to adapt",
        "I notice some tension in my neck"
      ].each do |phrase|
        it "does not trigger intervention for: '#{phrase[0..40]}...'" do
          result = monitor.assess(phrase)

          expect(result.crisis?).to be(false),
            "False positive: triggered crisis for safe phrase '#{phrase}'"
          expect(result.needs_intervention?).to be(false),
            "False positive: triggered intervention for safe phrase '#{phrase}'"
          expect(result.depth_score).to be < 0.3
        end
      end
    end

    context "with colloquial phrases that should NOT trigger" do
      # These are common expressions that contain crisis-like words but are not actual crises
      [
        "That joke killed me",
        "I killed it at work today",
        "I'm dying to try that new restaurant",
        "This is killing me with suspense",
        "I could just die of embarrassment",
        "That movie was so sad I died",
        "I'm dead tired",
        "I'm dying of boredom",
        "The suspense is killing me"
      ].each do |phrase|
        it "does not false positive for colloquial: '#{phrase}'" do
          result = monitor.assess(phrase)

          expect(result.crisis?).to be(false),
            "False positive: triggered crisis for colloquial phrase '#{phrase}'"
        end
      end
    end

    context "with session progression factors" do
      it "increases baseline score with iteration count" do
        session.update!(iteration_count: 5)
        result = monitor.assess("I notice a heaviness")

        # Session factors contribute a smaller baseline (max ~0.25 total from all session factors)
        # 5 iterations * 0.02 = 0.10, clamped to max 0.12
        expect(result.depth_score).to be >= 0.08
        expect(result.depth_score).to be < 0.3 # Should not trigger intervention from session alone
      end

      it "increases score after grounding interventions" do
        session.update!(grounding_insertions_count: 2)
        result = monitor.assess("I still feel heavy")

        # 2 groundings * 0.03 = 0.06, clamped to max 0.05
        expect(result.depth_score).to be >= 0.04
        expect(result.depth_score).to be < 0.3 # Should not trigger intervention from session alone
      end
    end
  end

  describe "#safety_level" do
    it "returns :green for low scores" do
      result = monitor.assess("I feel peaceful")
      expect(result.safety_level).to eq(:green)
    end

    it "returns :amber for moderate scores" do
      # Use multiple emotional intensity words to reach amber range (0.3+)
      # Each emotional word adds 0.1, so 3 words = 0.3
      result = monitor.assess("I feel terrified overwhelmed and panicking")
      expect(result.safety_level).to eq(:amber)
    end

    it "returns :crisis for maximum scores" do
      result = monitor.assess("I want to kill myself")
      expect(result.safety_level).to eq(:crisis)
    end
  end

  describe "#anonymized_triggers" do
    it "returns trigger types without user content" do
      result = monitor.assess("I want to kill myself today because of everything")
      triggers = result.anonymized_triggers

      expect(triggers.first[:type]).to eq(:crisis)
      expect(triggers.first).not_to have_key(:user_input)
      expect(triggers.first).not_to have_key(:matched_text)
    end

    it "includes pattern category for audit" do
      result = monitor.assess("I'm suicidal")
      triggers = result.anonymized_triggers

      expect(triggers.first[:pattern_category]).to be_present
    end
  end

  describe "intervention types" do
    context "when score is in grounding range (0.3-0.5)" do
      it "recommends grounding intervention" do
        # Use emotional words to push into amber range
        result = monitor.assess("I feel terrified and overwhelmed and panicking")

        expect(result.intervention_type).to eq(:grounding_needed)
      end
    end

    context "when score is in pause range (0.5-0.7)" do
      it "recommends pause intervention" do
        # Elevated risk adds 0.5, which puts us in pause range (0.5-0.7)
        result = monitor.assess("There's no hope left")

        expect(result.depth_score).to be >= 0.5
        expect(result.depth_score).to be < 0.7
        expect(result.intervention_type).to eq(:pause_suggested)
      end
    end

    context "when score is in integration range (0.7-0.9)" do
      it "recommends early integration" do
        # Elevated risk (0.5) + emotional intensity words (0.3) = 0.8
        # This should be in the integration range (0.7-0.9)
        result = monitor.assess("I feel hopeless and terrified overwhelmed panicking")

        expect(result.depth_score).to be >= 0.7
        expect(result.depth_score).to be < 0.9
        expect(result.intervention_type).to eq(:integration_needed)
      end
    end
  end

  # ============================================================================
  # COMPLIANCE VERIFICATION TESTS
  # ============================================================================
  # These tests verify regulatory compliance requirements.
  # DO NOT REMOVE without safety reviewer and DPO sign-off.
  # ============================================================================

  describe "COMPLIANCE: Deterministic Behavior" do
    # EU AI Act avoidance: System must be deterministic, not AI-based
    it "produces identical results for identical inputs (determinism requirement)" do
      input = "I feel terrified and hopeless about everything"

      results = 10.times.map do
        fresh_session = create(:journey_session, user: user, iteration_count: 0, current_depth_score: 0.0)
        fresh_monitor = described_class.new(fresh_session)
        result = fresh_monitor.assess(input)
        {
          score: result.depth_score,
          level: result.safety_level,
          intervention: result.intervention_type
        }
      end

      # All 10 runs must produce identical results
      expect(results.uniq.size).to eq(1),
        "COMPLIANCE FAILURE: Non-deterministic behaviour detected. " \
        "Results varied across runs: #{results.uniq}. " \
        "This would trigger EU AI Act High-Risk classification."
    end

    it "uses only pattern matching, not probabilistic methods" do
      # Verify the class doesn't include any ML/AI-related modules or methods
      expect(described_class.ancestors.map(&:to_s)).not_to include(/ML|AI|Neural|TensorFlow|PyTorch|Model/i)
      expect(described_class.instance_methods).not_to include(:predict, :infer, :train, :fit)
    end
  end

  describe "COMPLIANCE: Crisis Detection Reliability" do
    # User safety: Crisis detection must have ZERO false negatives
    # These are explicit test cases - not generated from patterns
    CRISIS_TEST_PHRASES = [
      # Immediate risk - must return score 1.0
      { phrase: "I want to kill myself", level: :immediate },
      { phrase: "I'm suicidal", level: :immediate },
      { phrase: "I want to end it all", level: :immediate },
      { phrase: "I don't want to live", level: :immediate },
      { phrase: "I want to die", level: :immediate },
      { phrase: "I'd rather be dead", level: :immediate },
      { phrase: "I want to hurt myself", level: :immediate },
      { phrase: "I'm going to self-harm", level: :immediate },
      { phrase: "I'm taking an overdose", level: :immediate },
      { phrase: "I have a plan to die", level: :immediate },
      # Elevated risk - must trigger intervention
      { phrase: "There's no hope", level: :elevated },
      { phrase: "I'm worthless", level: :elevated },
      { phrase: "I'm a burden", level: :elevated },
      { phrase: "I can't go on", level: :elevated },
      { phrase: "I can't cope", level: :elevated },
      { phrase: "I've given up on life", level: :elevated },
      { phrase: "I wish I was dead", level: :elevated },
      { phrase: "I wish I weren't alive", level: :elevated }
    ].freeze

    CRISIS_TEST_PHRASES.each do |test_case|
      it "detects #{test_case[:level]} risk: '#{test_case[:phrase]}'" do
        result = monitor.assess(test_case[:phrase])

        if test_case[:level] == :immediate
          expect(result.crisis?).to be(true),
            "COMPLIANCE FAILURE: Immediate risk phrase '#{test_case[:phrase]}' " \
            "did not trigger crisis (score: #{result.depth_score}). " \
            "This is a critical user safety issue."
          expect(result.depth_score).to eq(1.0)
        else
          expect(result.needs_intervention?).to be(true),
            "COMPLIANCE FAILURE: Elevated risk phrase '#{test_case[:phrase]}' " \
            "did not trigger intervention (score: #{result.depth_score}). " \
            "This is a user safety issue."
        end
      end
    end

    it "maintains crisis detection across session state changes" do
      # Crisis must be detected regardless of session state
      session.update!(current_depth_score: 0.0, iteration_count: 0)
      result1 = monitor.assess("I want to kill myself")

      session.update!(current_depth_score: 0.5, iteration_count: 3)
      fresh_monitor = described_class.new(session.reload)
      result2 = fresh_monitor.assess("I want to kill myself")

      expect(result1.crisis?).to be(true)
      expect(result2.crisis?).to be(true)
    end
  end

  describe "COMPLIANCE: Threshold Boundaries" do
    # Document current thresholds for audit purposes
    it "enforces documented threshold values" do
      expect(SafetyMonitor::THRESHOLDS[:green]).to eq(0.0..0.3)
      expect(SafetyMonitor::THRESHOLDS[:amber]).to eq(0.3..0.5)
      expect(SafetyMonitor::THRESHOLDS[:orange]).to eq(0.5..0.7)
      expect(SafetyMonitor::THRESHOLDS[:red]).to eq(0.7..0.9)
      expect(SafetyMonitor::THRESHOLDS[:crisis]).to eq(0.9..1.0)
    end

    it "maps thresholds to correct intervention types" do
      interventions = {
        0.25 => nil,           # GREEN - no intervention
        0.35 => :grounding_needed,  # AMBER
        0.55 => :pause_suggested,   # ORANGE
        0.75 => :integration_needed, # RED
        1.0 => :crisis              # CRISIS
      }

      interventions.each do |score, expected_intervention|
        session.update!(current_depth_score: score)
        fresh_monitor = described_class.new(session.reload)
        # Assess with neutral input to not change score significantly
        fresh_monitor.send(:determine_intervention)

        expect(fresh_monitor.intervention_type).to eq(expected_intervention),
          "Score #{score} should map to #{expected_intervention.inspect}, " \
          "got #{fresh_monitor.intervention_type.inspect}"
      end
    end
  end

  describe "COMPLIANCE: Audit Trail Support" do
    it "provides anonymized trigger data without personal content" do
      result = monitor.assess("I feel hopeless and terrified, there's no point anymore")

      anonymized = result.anonymized_triggers

      anonymized.each do |trigger|
        expect(trigger.keys).to contain_exactly(:type, :level, :pattern_category)
        expect(trigger.values.join(" ")).not_to include("hopeless", "terrified", "no point")
      end
    end

    it "includes pattern category for session review" do
      result = monitor.assess("I'm giving up on everything")

      anonymized = result.anonymized_triggers
      categories = anonymized.map { |t| t[:pattern_category] }

      expect(categories).to include("elevated_risk")
    end
  end
end
