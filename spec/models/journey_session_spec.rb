require 'rails_helper'

RSpec.describe JourneySession, type: :model do
  let(:user) { create(:user) }
  let(:journey_session) { create(:journey_session, user: user) }

  describe "associations" do
    it "belongs to user" do
      expect(journey_session.user).to eq(user)
    end

    it "has many session_iterations" do
      assoc = JourneySession.reflect_on_association(:session_iterations)
      expect(assoc.macro).to eq(:has_many)
    end

    it "has many safety_audit_logs" do
      log = SafetyAuditLog.create!(
        journey_session: journey_session,
        event_type: :grounding_inserted,
        depth_score_snapshot: 0.4,
        response_taken: "grounding_exercise"
      )
      expect(journey_session.safety_audit_logs).to include(log)
    end

    it "destroys session_iterations when destroyed" do
      assoc = JourneySession.reflect_on_association(:session_iterations)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "constants" do
    it "has MAX_ITERATIONS of 6" do
      expect(JourneySession::MAX_ITERATIONS).to eq(6)
    end

    it "has SOFT_TIME_LIMIT_MINUTES of 15" do
      expect(JourneySession::SOFT_TIME_LIMIT_MINUTES).to eq(15)
    end

    it "has HARD_TIME_LIMIT_MINUTES of 30" do
      expect(JourneySession::HARD_TIME_LIMIT_MINUTES).to eq(30)
    end

    it "defines all six spaces" do
      expect(JourneySession::SPACES).to match_array(%w[here there before after inside outside])
    end
  end

  describe "validations" do
    it "validates iteration_count is within range" do
      journey_session.iteration_count = -1
      expect(journey_session).not_to be_valid

      journey_session.iteration_count = 7
      expect(journey_session).not_to be_valid

      journey_session.iteration_count = 3
      expect(journey_session).to be_valid
    end

    it "validates current_depth_score is between 0 and 1" do
      journey_session.current_depth_score = -0.1
      expect(journey_session).not_to be_valid

      journey_session.current_depth_score = 1.1
      expect(journey_session).not_to be_valid

      journey_session.current_depth_score = 0.5
      expect(journey_session).to be_valid
    end

    it "validates current_space is a valid space" do
      journey_session.current_space = "invalid"
      expect(journey_session).not_to be_valid

      journey_session.current_space = "here"
      expect(journey_session).to be_valid
    end

    it "allows nil current_space" do
      journey_session.current_space = nil
      expect(journey_session).to be_valid
    end
  end

  describe "state machine" do
    it "starts in welcome state" do
      new_session = JourneySession.new(user: user)
      expect(new_session.state).to eq("welcome")
    end

    describe "state enum" do
      it "defines all expected states" do
        expected_states = %w[welcome space_selection emergence_cycle integration paused completed abandoned]
        expect(JourneySession.states.keys).to match_array(expected_states)
      end

      it "uses correct integer mappings" do
        expect(JourneySession.states["welcome"]).to eq(0)
        expect(JourneySession.states["completed"]).to eq(5)
        expect(JourneySession.states["abandoned"]).to eq(6)
      end
    end

    describe "transitions" do
      it "transitions from welcome to space_selection on give_consent" do
        session = create(:journey_session, state: :welcome)
        session.give_consent!
        expect(session.state).to eq("space_selection")
      end

      it "transitions from space_selection to emergence_cycle on select_space" do
        session = create(:journey_session, state: :space_selection)
        session.select_space!
        expect(session.state).to eq("emergence_cycle")
        expect(session.started_at).not_to be_nil
      end

      it "allows pausing from emergence_cycle" do
        session = create(:journey_session, state: :emergence_cycle)
        session.pause!
        expect(session.state).to eq("paused")
      end

      it "allows completing from integration" do
        # Test the AASM transition is allowed
        session = build(:journey_session, state: :integration)
        expect(session.may_complete?).to be true
      end

      it "allows abandoning from any active state" do
        %i[welcome space_selection emergence_cycle integration paused].each do |state|
          session = create(:journey_session, state: state)
          session.abandon!
          expect(session.state).to eq("abandoned")
        end
      end
    end
  end

  describe "scopes" do
    it ".active returns sessions in active states" do
      active = create(:journey_session, state: :emergence_cycle)
      completed = create(:journey_session, state: :completed)

      expect(JourneySession.active).to include(active)
      expect(JourneySession.active).not_to include(completed)
    end

    it ".completed_sessions returns only completed sessions" do
      completed = create(:journey_session, state: :completed)
      active = create(:journey_session, state: :emergence_cycle)

      expect(JourneySession.completed_sessions).to include(completed)
      expect(JourneySession.completed_sessions).not_to include(active)
    end

    it ".for_user returns sessions for specific user" do
      other_user = create(:user)
      other_session = create(:journey_session, user: other_user)

      expect(JourneySession.for_user(user)).to include(journey_session)
      expect(JourneySession.for_user(user)).not_to include(other_session)
    end
  end

  describe "instance methods" do
    describe "#duration_minutes" do
      it "returns 0 when started_at is nil" do
        journey_session.started_at = nil
        expect(journey_session.duration_minutes).to eq(0)
      end

      it "calculates minutes since started_at" do
        journey_session.started_at = 10.minutes.ago
        expect(journey_session.duration_minutes).to be_within(1).of(10)
      end
    end

    describe "#at_iteration_limit?" do
      it "returns true when iteration_count equals MAX_ITERATIONS" do
        journey_session.iteration_count = JourneySession::MAX_ITERATIONS
        expect(journey_session.at_iteration_limit?).to be true
      end

      it "returns false when under limit" do
        journey_session.iteration_count = 3
        expect(journey_session.at_iteration_limit?).to be false
      end
    end

    describe "#at_time_limit?" do
      it "returns true when duration exceeds HARD_TIME_LIMIT_MINUTES" do
        journey_session.started_at = 31.minutes.ago
        expect(journey_session.at_time_limit?).to be true
      end

      it "returns false when under limit" do
        journey_session.started_at = 15.minutes.ago
        expect(journey_session.at_time_limit?).to be false
      end
    end

    describe "#should_warn_time_limit?" do
      it "returns true when at soft limit and not yet warned" do
        journey_session.started_at = 16.minutes.ago
        journey_session.soft_time_limit_warned = false
        expect(journey_session.should_warn_time_limit?).to be true
      end

      it "returns false when already warned" do
        journey_session.started_at = 16.minutes.ago
        journey_session.soft_time_limit_warned = true
        expect(journey_session.should_warn_time_limit?).to be false
      end
    end

    describe "#can_continue_iteration?" do
      it "returns true when under both limits" do
        journey_session.iteration_count = 3
        journey_session.started_at = 10.minutes.ago
        expect(journey_session.can_continue_iteration?).to be true
      end

      it "returns false when at iteration limit" do
        journey_session.iteration_count = JourneySession::MAX_ITERATIONS
        journey_session.started_at = 10.minutes.ago
        expect(journey_session.can_continue_iteration?).to be false
      end

      it "returns false when at time limit" do
        journey_session.iteration_count = 3
        journey_session.started_at = 31.minutes.ago
        expect(journey_session.can_continue_iteration?).to be false
      end
    end

    describe "#advance_iteration!" do
      it "increments iteration_count and updates depth score" do
        journey_session.iteration_count = 2
        journey_session.advance_iteration!(0.45)

        expect(journey_session.iteration_count).to eq(3)
        expect(journey_session.current_depth_score).to eq(0.45)
      end
    end

    describe "#active?" do
      it "returns true for active states" do
        %w[welcome space_selection emergence_cycle].each do |state|
          journey_session.state = state
          expect(journey_session.active?).to be true
        end
      end

      it "returns false for non-active states" do
        %w[integration paused completed abandoned].each do |state|
          journey_session.state = state
          expect(journey_session.active?).to be false
        end
      end
    end

    describe "#had_safety_interventions?" do
      it "returns true when safety_audit_logs exist" do
        SafetyAuditLog.create!(
          journey_session: journey_session,
          event_type: :grounding_inserted,
          depth_score_snapshot: 0.4,
          response_taken: "grounding"
        )
        expect(journey_session.had_safety_interventions?).to be true
      end

      it "returns false when no safety_audit_logs exist" do
        expect(journey_session.had_safety_interventions?).to be false
      end
    end
  end

  describe "encrypted fields" do
    it "has encrypted attributes defined" do
      # Check the model declares encrypts for these attributes
      expect(JourneySession.encrypted_attributes).to include(:current_space)
      expect(JourneySession.encrypted_attributes).to include(:session_summary)
      expect(JourneySession.encrypted_attributes).to include(:pending_question)
      expect(JourneySession.encrypted_attributes).to include(:reflected_words_cache)
    end
  end

  describe "paper_trail" do
    it "has paper_trail configured" do
      expect(JourneySession.included_modules).to include(PaperTrail::Model::InstanceMethods)
    end
  end
end
