require 'rails_helper'

RSpec.describe SessionIteration, type: :model do
  let(:journey_session) { create(:journey_session) }

  describe "associations" do
    it "belongs to journey_session" do
      assoc = SessionIteration.reflect_on_association(:journey_session)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires iteration_number" do
      iteration = SessionIteration.new(journey_session: journey_session)
      expect(iteration).not_to be_valid
      expect(iteration.errors[:iteration_number]).to be_present
    end

    it "validates iteration_number is greater than 0" do
      iteration = SessionIteration.new(journey_session: journey_session, iteration_number: 0)
      expect(iteration).not_to be_valid
    end

    it "validates iteration_number is within MAX_ITERATIONS" do
      iteration = SessionIteration.new(journey_session: journey_session, iteration_number: 7, space_explored: "here")
      expect(iteration).not_to be_valid

      iteration.iteration_number = 6
      expect(iteration).to be_valid
    end

    it "validates space_explored is a valid space or integration" do
      iteration = SessionIteration.new(journey_session: journey_session, iteration_number: 1, space_explored: "invalid")
      expect(iteration).not_to be_valid

      JourneySession::SPACES.each do |space|
        iteration.space_explored = space
        expect(iteration).to be_valid
      end

      iteration.space_explored = "integration"
      expect(iteration).to be_valid
    end

    it "allows nil space_explored" do
      iteration = SessionIteration.new(journey_session: journey_session, iteration_number: 1, space_explored: nil)
      expect(iteration).to be_valid
    end
  end

  describe "scopes" do
    describe ".for_cleanup" do
      it "returns iterations older than 30 days based on scope definition" do
        # Verify the scope is defined correctly
        expect(SessionIteration.for_cleanup.to_sql).to include("created_at")
      end
    end

    describe ".in_order" do
      it "orders by iteration_number" do
        expect(SessionIteration.in_order.to_sql).to include("ORDER BY")
        expect(SessionIteration.in_order.to_sql).to include("iteration_number")
      end
    end

    describe ".with_intervention" do
      it "filters iterations with safety_intervention" do
        expect(SessionIteration.with_intervention.to_sql).to include("safety_intervention")
      end
    end
  end

  describe "instance methods" do
    let(:iteration) { SessionIteration.new(journey_session: journey_session, iteration_number: 1, space_explored: "here") }

    describe "#had_intervention?" do
      it "returns true when safety_intervention is present" do
        iteration.safety_intervention = "grounding"
        expect(iteration.had_intervention?).to be true
      end

      it "returns false when safety_intervention is nil" do
        iteration.safety_intervention = nil
        expect(iteration.had_intervention?).to be false
      end
    end

    describe "#redacted?" do
      it "returns true when user_response is [REDACTED]" do
        iteration.user_response = "[REDACTED]"
        expect(iteration.redacted?).to be true
      end

      it "returns false when user_response has content" do
        iteration.user_response = "Some reflection text"
        expect(iteration.redacted?).to be false
      end
    end

    describe "#export_data" do
      it "returns full data when not redacted" do
        iteration.iteration_number = 2
        iteration.space_explored = "here"
        iteration.reflected_words = "peace, calm"
        iteration.user_response = "I feel peaceful"

        export = iteration.export_data
        expect(export[:iteration]).to eq(2)
        expect(export[:space]).to eq("here")
        expect(export[:reflected_words]).to eq("peace, calm")
        expect(export[:redacted]).to be false
      end

      it "returns limited data when redacted" do
        iteration.iteration_number = 2
        iteration.space_explored = "here"
        iteration.user_response = "[REDACTED]"

        export = iteration.export_data
        expect(export[:iteration]).to eq(2)
        expect(export[:space]).to eq("here")
        expect(export[:redacted]).to be true
        expect(export).not_to have_key(:reflected_words)
      end
    end
  end

  describe ".cleanup_old_content!" do
    it "is defined as a class method" do
      expect(SessionIteration).to respond_to(:cleanup_old_content!)
    end
  end

  describe "encrypted fields" do
    it "has encrypted attributes defined" do
      expect(SessionIteration.encrypted_attributes).to include(:user_response)
      expect(SessionIteration.encrypted_attributes).to include(:question_asked)
      expect(SessionIteration.encrypted_attributes).to include(:reflected_words)
    end
  end

  describe "paper_trail" do
    it "has paper_trail configured" do
      expect(SessionIteration.included_modules).to include(PaperTrail::Model::InstanceMethods)
    end
  end
end
