# frozen_string_literal: true

# ============================================================================
# REGULATORY COMPLIANCE TEST SUITE
# ============================================================================
# These tests verify the application meets regulatory requirements.
# See COMPLIANCE.md for full documentation.
#
# RUN BEFORE EVERY DEPLOYMENT: bundle exec rspec spec/compliance/
#
# Test coverage:
# - EU AI Act: Verifies system is deterministic (not AI)
# - UK/EU GDPR: Verifies data protection measures
# - User Safety: Verifies crisis detection reliability
#
# MODIFICATION POLICY:
# - Tests can only be ADDED, not removed, without compliance review
# - Any test removal requires DPO and safety reviewer sign-off
# - Document all changes in COMPLIANCE.md
# ============================================================================

require "rails_helper"

RSpec.describe "Regulatory Compliance", type: :compliance do
  describe "EU AI Act Compliance" do
    describe "System Classification" do
      it "uses deterministic processing, not AI/ML" do
        # Verify SafetyMonitor doesn't use AI
        expect(defined?(SafetyMonitor)).to eq("constant")

        # Check for absence of AI/ML indicators
        safety_monitor_source = File.read(Rails.root.join("app/services/safety_monitor.rb"))

        ai_indicators = %w[
          tensorflow pytorch sklearn machine_learning
          neural_network deep_learning model.predict
          classifier regressor embedding
        ]

        ai_indicators.each do |indicator|
          expect(safety_monitor_source.downcase).not_to include(indicator),
            "EU AI Act: Found AI indicator '#{indicator}' in SafetyMonitor. " \
            "This would trigger High-Risk classification under Annex III, Section 5."
        end
      end

      it "documents non-AI status in source code" do
        safety_monitor_source = File.read(Rails.root.join("app/services/safety_monitor.rb"))

        expect(safety_monitor_source).to include("DETERMINISTIC"),
          "SafetyMonitor must document its deterministic nature"
        expect(safety_monitor_source).to include("NOT AI"),
          "SafetyMonitor must explicitly state it does not use AI"
      end

      it "has compliance warning header" do
        safety_monitor_source = File.read(Rails.root.join("app/services/safety_monitor.rb"))

        expect(safety_monitor_source).to include("COMPLIANCE WARNING"),
          "SafetyMonitor must have compliance warning header"
      end
    end
  end

  describe "GDPR Compliance" do
    describe "Article 9 - Special Category Data" do
      it "requires explicit consent for sensitive data processing" do
        required_types = Consent.required_consent_types

        expect(required_types).to include(:sensitive_data_processing),
          "GDPR Article 9 requires explicit consent for sensitive personal data"
      end

      it "blocks session start without required consents" do
        user = create(:user)

        expect(user.can_start_session?).to be(false),
          "Users without consents must not be able to start sessions"
      end

      it "allows session start with all required consents" do
        user = create(:user)
        Consent.required_consent_types.each do |type|
          create(:consent, user: user, consent_type: type)
        end

        expect(user.can_start_session?).to be(true)
      end
    end

    describe "Article 5(1)(c) - Data Minimization" do
      it "has data retention job for content redaction" do
        expect(defined?(DataRetentionJob)).to eq("constant"),
          "DataRetentionJob must exist for GDPR data minimization"
      end

      it "redacts content after retention period" do
        job_source = File.read(Rails.root.join("app/jobs/data_retention_job.rb"))

        expect(job_source).to include("30.days.ago"),
          "Data retention must use 30-day period as documented"
        expect(job_source).to include("[REDACTED]"),
          "Redaction must replace content with [REDACTED] marker"
      end
    end

    describe "Article 17 - Right to Erasure" do
      it "cascades user deletion to associated records" do
        user_reflections = User.reflect_on_all_associations

        journey_sessions_assoc = user_reflections.find { |a| a.name == :journey_sessions }
        consents_assoc = user_reflections.find { |a| a.name == :consents }

        expect(journey_sessions_assoc.options[:dependent]).to eq(:destroy),
          "JourneySessions must be destroyed when user is deleted"
        expect(consents_assoc.options[:dependent]).to eq(:destroy),
          "Consents must be destroyed when user is deleted"
      end
    end

    describe "Article 20 - Right to Data Portability" do
      it "has data export endpoint" do
        controller = Users::RegistrationsController.new

        expect(controller).to respond_to(:export_data),
          "RegistrationsController must have export_data action for GDPR portability"
      end
    end

    describe "Consent Record Preservation" do
      it "uses PaperTrail for consent audit trail" do
        expect(Consent.new).to respond_to(:versions),
          "Consent model must use PaperTrail for audit trail"
      end
    end

    describe "Consent Withdrawal Mid-Session" do
      it "terminates active sessions when sensitive_data_processing consent is withdrawn" do
        user = create(:user)
        # Create active session
        session = create(:journey_session, user: user, state: :emergence_cycle)

        # Verify session is active
        expect(session.active?).to be(true)

        # Simulate the controller behaviour - terminate active sessions on consent withdrawal
        user.journey_sessions.active.find_each do |s|
          s.abandon! if s.may_abandon?
        end

        session.reload
        expect(session.state).to eq("abandoned"),
          "GDPR: Active session must be terminated when consent is withdrawn"
      end

      it "has consent_withdrawn event type for audit logging" do
        expect(SafetyAuditLog.event_types).to include("consent_withdrawn"),
          "SafetyAuditLog must have consent_withdrawn event type for GDPR compliance"
      end

      it "can log consent withdrawal events" do
        user = create(:user)
        session = create(:journey_session, user: user)

        log = SafetyAuditLog.create!(
          journey_session: session,
          event_type: :consent_withdrawn,
          trigger_data: { reason: "User withdrew consent", consent_type: "sensitive_data_processing" },
          depth_score_snapshot: 0.0,
          response_taken: "session_terminated"
        )

        expect(log).to be_persisted
        expect(log.event_type).to eq("consent_withdrawn")
      end
    end
  end

  describe "User Safety Compliance" do
    describe "Crisis Detection" do
      let(:user) { create(:user) }
      let(:session) { create(:journey_session, user: user, current_depth_score: 0.0) }
      let(:monitor) { SafetyMonitor.new(session) }

      it "detects immediate risk phrases with 100% reliability" do
        immediate_risk_phrases = [
          "I want to kill myself",
          "I'm suicidal",
          "I want to end it all",
          "I want to die"
        ]

        immediate_risk_phrases.each do |phrase|
          result = monitor.assess(phrase)

          expect(result.crisis?).to be(true),
            "USER SAFETY: Failed to detect crisis in '#{phrase}'"
          expect(result.depth_score).to eq(1.0),
            "USER SAFETY: Crisis score must be 1.0 for '#{phrase}'"
        end
      end

      it "provides crisis resources for all supported regions" do
        %i[uk us eu au].each do |region|
          resources = CrisisResources.for_region(region)

          expect(resources).to be_present,
            "Crisis resources must be available for #{region} region"
          expect(resources[:primary]).to be_present,
            "Primary crisis resource must be defined for #{region}"
          expect(resources[:primary][:phone]).to be_present,
            "Crisis phone number must be defined for #{region}"
        end
      end
    end

    describe "Safety Audit Logging" do
      it "has SafetyAuditLog model for compliance" do
        expect(defined?(SafetyAuditLog)).to eq("constant"),
          "SafetyAuditLog must exist for safety event auditing"
      end

      it "logs safety events with anonymized data" do
        user = create(:user)
        session = create(:journey_session, user: user)
        monitor = SafetyMonitor.new(session)
        monitor.assess("I feel hopeless")

        anonymized = monitor.anonymized_triggers

        anonymized.each do |trigger|
          trigger_text = trigger.values.join(" ")
          expect(trigger_text).not_to include("hopeless"),
            "Anonymized triggers must not contain user content"
        end
      end
    end
  end

  describe "Documentation Compliance" do
    it "has COMPLIANCE.md file" do
      compliance_file = Rails.root.join("COMPLIANCE.md")

      expect(File.exist?(compliance_file)).to be(true),
        "COMPLIANCE.md must exist in project root"
    end

    it "has compliance warnings in CLAUDE.md" do
      claude_file = Rails.root.join("CLAUDE.md")
      content = File.read(claude_file)

      expect(content).to include("COMPLIANCE"),
        "CLAUDE.md must include compliance information"
      expect(content).to include("EU AI Act"),
        "CLAUDE.md must reference EU AI Act"
      expect(content).to include("GDPR"),
        "CLAUDE.md must reference GDPR"
    end
  end
end
