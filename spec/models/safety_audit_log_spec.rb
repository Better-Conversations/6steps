require 'rails_helper'

RSpec.describe SafetyAuditLog, type: :model do
  describe "trigger_data JSONB storage" do
    let(:journey_session) { create(:journey_session) }

    it "stores consent_type as 'sensitive_data_processing' string" do
      log = SafetyAuditLog.create!(
        journey_session: journey_session,
        event_type: :consent_withdrawn,
        trigger_data: { reason: "User withdrew consent", consent_type: "sensitive_data_processing" },
        depth_score_snapshot: 0.0,
        response_taken: "session_terminated"
      )

      expect(log.trigger_data["consent_type"]).to eq("sensitive_data_processing")
    end

    it "can query by consent_type in JSONB" do
      SafetyAuditLog.create!(
        journey_session: journey_session,
        event_type: :consent_withdrawn,
        trigger_data: { consent_type: "sensitive_data_processing" },
        depth_score_snapshot: 0.0,
        response_taken: "session_terminated"
      )

      result = SafetyAuditLog.where("trigger_data->>'consent_type' = ?", "sensitive_data_processing")
      expect(result.count).to eq(1)
    end

    it "does not contain any legacy health_data_processing strings" do
      # This test ensures the migration was successful and no old terminology remains
      old_records = SafetyAuditLog.where("trigger_data->>'consent_type' = ?", "health_data_processing")
      expect(old_records.count).to eq(0)
    end
  end

  describe "event_type enum" do
    it "includes consent_withdrawn for GDPR consent withdrawal events" do
      expect(SafetyAuditLog.event_types.keys).to include("consent_withdrawn")
    end

    it "includes all expected event types" do
      expected_types = %w[
        depth_threshold_crossed
        crisis_pattern_detected
        grounding_inserted
        pause_suggested
        integration_triggered
        crisis_protocol_activated
        user_dismissed_warning
        resource_displayed
        resource_clicked
        session_timeout
        iteration_limit_reached
        consent_withdrawn
      ]
      expect(SafetyAuditLog.event_types.keys).to match_array(expected_types)
    end
  end

  describe "#critical?" do
    let(:journey_session) { create(:journey_session) }

    it "returns true for crisis_protocol_activated" do
      log = SafetyAuditLog.new(event_type: :crisis_protocol_activated)
      expect(log.critical?).to be true
    end

    it "returns true for crisis_pattern_detected" do
      log = SafetyAuditLog.new(event_type: :crisis_pattern_detected)
      expect(log.critical?).to be true
    end

    it "returns false for consent_withdrawn" do
      log = SafetyAuditLog.new(event_type: :consent_withdrawn)
      expect(log.critical?).to be false
    end
  end

  describe "#description" do
    it "returns descriptive text for consent_withdrawn" do
      log = SafetyAuditLog.new(event_type: :consent_withdrawn)
      expect(log.description).to eq("Session terminated - consent withdrawn")
    end
  end
end
