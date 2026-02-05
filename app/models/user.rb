# frozen_string_literal: true

class User < ApplicationRecord
  has_paper_trail

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :journey_sessions, dependent: :destroy
  has_many :consents, dependent: :destroy
  has_many :created_invites, class_name: "Invite", foreign_key: "created_by_id", dependent: :nullify
  has_one :used_invite, class_name: "Invite", foreign_key: "used_by_id", dependent: :nullify

  # Enums
  enum :region, { uk: 0, us: 1, eu: 2, au: 3, other: 99 }, prefix: true
  enum :role, { user: 0, session_reviewer: 1, admin: 2 }, prefix: true

  # Validations
  validates :region, presence: true

  # Instance methods

  # Check if user has active consent for a specific type
  def active_consent_for?(consent_type)
    consents.active.where(consent_type: consent_type).exists?
  end

  # Check if user has all required consents to start a session
  def can_start_session?
    Consent.required_consent_types.all? { |type| active_consent_for?(type) }
  end

  # Check if user has session reviewer or admin role
  def can_review_sessions?
    role_session_reviewer? || role_admin?
  end

  # Check if this is the user's first session (for onboarding)
  def first_time_user?
    journey_sessions.where(state: :completed).count.zero?
  end

  # Count of completed sessions
  def completed_sessions_count
    journey_sessions.where(state: :completed).count
  end
end
