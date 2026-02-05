# frozen_string_literal: true

# ============================================================================
# COMPLIANCE WARNING - GDPR LAWFUL BASIS
# ============================================================================
# This model manages consent records required under UK/EU GDPR Article 6 & 9.
# Modifications require DPO/Legal review. See COMPLIANCE.md Section 4.
#
# Required consents (defined in .required_consent_types):
# - terms_of_service: General terms
# - privacy_policy: Privacy policy acceptance
# - sensitive_data_processing: GDPR Article 9 explicit consent for special category data
# - session_reflections: Understanding of data handling
#
# Consent records must be preserved for audit purposes even after withdrawal.
# ============================================================================

class Consent < ApplicationRecord
  has_paper_trail

  belongs_to :user

  # Enums for consent types
  enum :consent_type, {
    terms_of_service: 0,
    privacy_policy: 1,
    sensitive_data_processing: 2,
    session_reflections: 3,
    anonymized_research: 4,
    marketing_communications: 5
  }, prefix: true

  # Scopes
  scope :active, -> { where(withdrawn_at: nil) }
  scope :withdrawn, -> { where.not(withdrawn_at: nil) }
  scope :for_type, ->(type) { where(consent_type: type) }
  scope :requiring_renewal, -> { active.where("given_at < ?", 1.year.ago) }

  # Validations
  validates :consent_type, presence: true
  validates :version, presence: true
  validates :given_at, presence: true
  validates :consent_type, uniqueness: {
    scope: [ :user_id ],
    conditions: -> { active },
    message: "already has an active consent"
  }

  # Instance methods

  # Withdraw this consent with an optional reason
  def withdraw!(reason: nil)
    update!(withdrawn_at: Time.current, withdrawal_reason: reason)
  end

  # Check if this consent has been withdrawn
  def withdrawn?
    withdrawn_at.present?
  end

  # Check if this consent is still active
  def active?
    withdrawn_at.nil?
  end

  # Check if this consent needs renewal (older than 1 year)
  def needs_renewal?
    active? && given_at < 1.year.ago
  end

  # Class methods

  # Get the current version for a consent type
  def self.current_version_for(consent_type)
    case consent_type.to_sym
    when :terms_of_service then "1.1"
    when :privacy_policy then "1.1"
    when :sensitive_data_processing then "1.1"
    when :session_reflections then "1.1"
    when :anonymized_research then "1.0"
    when :marketing_communications then "1.0"
    else "1.0"
    end
  end

  # Required consent types for using the app
  def self.required_consent_types
    %i[terms_of_service privacy_policy sensitive_data_processing session_reflections]
  end
end
