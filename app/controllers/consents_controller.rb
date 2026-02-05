# frozen_string_literal: true

# ============================================================================
# COMPLIANCE WARNING - GDPR CONSENT MANAGEMENT
# ============================================================================
# This controller manages user consent under GDPR Articles 6 & 9.
# Consent withdrawal must be handled carefully:
# - Active sessions must be terminated when sensitive_data_processing is withdrawn
# - Audit trail must be preserved
# See COMPLIANCE.md for requirements.
# ============================================================================

class ConsentsController < ApplicationController
  before_action :authenticate_user!

  CONSENT_INFO = {
    terms_of_service: {
      title: "Terms of Service",
      description: "I agree to the Terms of Service and understand that Six Steps is a tool for structured self-reflection. It is not intended as a substitute for professional coaching, counselling, or therapy. If I need support, I will seek appropriate professional help.",
      version: "1.1",
      required: true
    },
    privacy_policy: {
      title: "Privacy Policy",
      description: "I have read and agree to the Privacy Policy, including how my data is collected, processed, and stored.",
      version: "1.1",
      required: true
    },
    sensitive_data_processing: {
      title: "Sensitive Data Processing",
      description: "I understand that my responses during reflection sessions may contain sensitive personal information. I consent to this data being processed to provide the reflection service.",
      version: "1.1",
      required: true
    },
    session_reflections: {
      title: "Session Reflections",
      description: "I understand that my reflection responses will be stored (encrypted) for up to 30 days to allow me to review my sessions. After 30 days, the content will be automatically redacted.",
      version: "1.1",
      required: true
    }
  }.freeze

  def index
    @consents = current_user.consents.active.index_by(&:consent_type)
    @consent_info = CONSENT_INFO
  end

  def create
    consent_type = params[:consent_type]&.to_sym

    unless CONSENT_INFO.key?(consent_type)
      redirect_to consents_path, alert: "Invalid consent type."
      return
    end

    # Check if active consent already exists
    if current_user.active_consent_for?(consent_type)
      redirect_to consents_path, notice: "You have already provided this consent."
      return
    end

    consent = current_user.consents.build(
      consent_type: consent_type,
      version: CONSENT_INFO[consent_type][:version],
      given_at: Time.current,
      ip_address: request.remote_ip
    )

    if consent.save
      redirect_to consents_path, notice: "Consent recorded. Thank you."
    else
      redirect_to consents_path, alert: "Unable to record consent. Please try again."
    end
  end

  def withdraw
    consent_type = params[:consent_type]&.to_sym
    reason = params[:reason]

    consent = current_user.consents.active.find_by(consent_type: consent_type)

    if consent
      # COMPLIANCE: Terminate active sessions when sensitive data consent is withdrawn
      # This ensures we stop processing sensitive data immediately upon withdrawal
      sessions_terminated = 0
      if consent_type == :sensitive_data_processing
        sessions_terminated = terminate_active_sessions(reason: "Consent withdrawn")
      end

      consent.update(
        withdrawn_at: Time.current,
        withdrawal_reason: reason
      )

      notice = "Consent withdrawn successfully."
      notice += " #{sessions_terminated} active session(s) were terminated." if sessions_terminated > 0

      redirect_to consents_path, notice: notice
    else
      redirect_to consents_path, alert: "No active consent found to withdraw."
    end
  end

  private

  # Terminate all active sessions for the current user
  # Called when sensitive_data_processing consent is withdrawn
  def terminate_active_sessions(reason:)
    active_sessions = current_user.journey_sessions.active
    count = 0

    active_sessions.find_each do |session|
      # Use AASM abandon event if available, otherwise update state directly
      if session.may_abandon?
        session.abandon!
      else
        session.update!(state: :abandoned)
      end

      # Log the termination for audit purposes
      SafetyAuditLog.create!(
        journey_session: session,
        event_type: :consent_withdrawn,
        trigger_data: { reason: reason, consent_type: "sensitive_data_processing" },
        depth_score_snapshot: session.current_depth_score,
        response_taken: "session_terminated"
      )

      count += 1
    end

    count
  end
end
