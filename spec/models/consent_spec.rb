# frozen_string_literal: true

require "rails_helper"

RSpec.describe Consent, type: :model do
  describe "consent_type enum" do
    it "defines all required consent types" do
      expected_types = %w[terms_of_service privacy_policy sensitive_data_processing session_reflections anonymized_research marketing_communications]
      expect(Consent.consent_types.keys).to match_array(expected_types)
    end

    it "uses correct integer mappings" do
      expect(Consent.consent_types["terms_of_service"]).to eq(0)
      expect(Consent.consent_types["privacy_policy"]).to eq(1)
      expect(Consent.consent_types["sensitive_data_processing"]).to eq(2)
      expect(Consent.consent_types["session_reflections"]).to eq(3)
    end
  end

  describe ".required_consent_types" do
    it "includes sensitive_data_processing" do
      expect(Consent.required_consent_types).to include(:sensitive_data_processing)
    end

    it "returns all four required types" do
      expected = %i[terms_of_service privacy_policy sensitive_data_processing session_reflections]
      expect(Consent.required_consent_types).to match_array(expected)
    end
  end

  describe ".current_version_for" do
    it "returns version for sensitive_data_processing" do
      expect(Consent.current_version_for(:sensitive_data_processing)).to eq("1.1")
    end
  end

  describe "consent workflow" do
    let(:user) { create(:user) }

    it "can be created with sensitive_data_processing type" do
      consent = create(:consent, user: user, consent_type: :sensitive_data_processing)
      expect(consent).to be_persisted
      expect(consent.consent_type).to eq("sensitive_data_processing")
    end

    it "can be withdrawn" do
      consent = create(:consent, user: user, consent_type: :sensitive_data_processing)
      consent.withdraw!(reason: "User requested")

      expect(consent.withdrawn?).to be true
      expect(consent.withdrawal_reason).to eq("User requested")
    end
  end
end
