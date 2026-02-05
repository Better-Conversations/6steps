# frozen_string_literal: true

# Invite handles secure invite links for user registration.
# Only users with a valid, unexpired invite can register.
#
# Invites can be single-use (default) or multi-use (for community sharing).
# Multi-use invites can optionally have a max_uses limit.
class Invite < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :used_by, class_name: "User", optional: true

  # Callbacks
  before_validation :generate_token, on: :create
  before_validation :set_default_expiry, on: :create

  # Validations
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :max_uses, numericality: { greater_than: 0, allow_nil: true }
  validate :email_format, if: -> { email.present? }
  validate :multi_use_cannot_have_email_restriction
  validate :max_uses_only_for_multi_use

  # Scopes - updated to handle multi-use invites
  scope :valid, -> {
    not_expired.where(
      "multi_use = ? OR (multi_use = ? AND used_at IS NULL)",
      true, false
    ).where(
      "max_uses IS NULL OR use_count < max_uses"
    )
  }
  scope :not_expired, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :used, -> { where.not(used_at: nil) }
  scope :unused, -> { where(used_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :single_use, -> { where(multi_use: false) }
  scope :multi_use_invites, -> { where(multi_use: true) }

  # Default expiry period (7 days)
  DEFAULT_EXPIRY_DAYS = 7

  # Class methods

  # Find a valid invite by token
  def self.find_valid(token)
    valid.find_by(token: token)
  end

  # Generate a new invite (can be called by admin)
  def self.create_invite(created_by:, email: nil, notes: nil, expires_in: DEFAULT_EXPIRY_DAYS.days,
                         multi_use: false, max_uses: nil)
    create!(
      created_by: created_by,
      email: email,
      notes: notes,
      expires_at: Time.current + expires_in,
      multi_use: multi_use,
      max_uses: max_uses
    )
  end

  # Instance methods

  # Check if invite is still valid for use
  def valid_for_use?
    return false if expired?
    return false if max_uses_reached?

    # Multi-use invites remain valid until expired or max uses reached
    # Single-use invites are invalid once used
    multi_use? || used_at.nil?
  end

  # Check if invite is expired
  def expired?
    expires_at <= Time.current
  end

  # Check if invite has been used (at least once)
  def used?
    used_at.present?
  end

  # Check if max uses has been reached (only applies when max_uses is set)
  def max_uses_reached?
    max_uses.present? && use_count >= max_uses
  end

  # Check if this is a multi-use (general) invite
  def multi_use?
    multi_use
  end

  # Returns remaining uses (nil if unlimited)
  def remaining_uses
    return nil unless max_uses.present?
    [ max_uses - use_count, 0 ].max
  end

  # Mark invite as used by a user
  # Uses pessimistic locking to prevent race conditions on multi-use invites
  def mark_used!(user)
    with_lock do
      if multi_use?
        # Check max_uses cap before incrementing
        if max_uses.present? && use_count >= max_uses
          raise ActiveRecord::RecordInvalid.new(self), "Invite has reached maximum uses"
        end

        # Multi-use: increment counter, update used_at only on first use
        update!(
          use_count: use_count + 1,
          used_at: used_at || Time.current,
          used_by: used_by || user
        )
      else
        # Single-use: mark as fully used
        update!(
          used_at: Time.current,
          used_by: user,
          use_count: 1
        )
      end
    end
  end

  # Check if invite is restricted to a specific email
  def email_restricted?
    email.present?
  end

  # Check if email matches restriction (if any)
  def valid_for_email?(check_email)
    return true unless email_restricted?

    email.downcase == check_email.to_s.downcase
  end

  # Generate the full invite URL
  def invite_url(host: nil)
    url_options = Rails.application.config.action_mailer.default_url_options || {}
    host ||= url_options[:host] || "localhost"
    port = url_options[:port]
    protocol = url_options[:protocol] || (Rails.env.production? ? "https" : "http")

    # Build the host:port string if port is present and not already in host
    host_with_port = if host.include?("://")
      host
    elsif port.present? && !host.include?(":")
      "#{protocol}://#{host}:#{port}"
    else
      "#{protocol}://#{host}"
    end

    "#{host_with_port}/users/sign_up?invite=#{token}"
  end

  # Status for display
  def status
    return :expired if expired?
    return :exhausted if max_uses_reached?
    return :used if !multi_use? && used?
    return :active if multi_use? && valid_for_use?

    :valid
  end

  # Time remaining until expiry
  def time_remaining
    return nil if expired?
    return nil if !multi_use? && used?

    expires_at - Time.current
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_default_expiry
    self.expires_at ||= DEFAULT_EXPIRY_DAYS.days.from_now
  end

  def email_format
    unless email =~ URI::MailTo::EMAIL_REGEXP
      errors.add(:email, "is not a valid email address")
    end
  end

  def multi_use_cannot_have_email_restriction
    if multi_use? && email.present?
      errors.add(:email, "cannot be set for multi-use invites")
    end
  end

  def max_uses_only_for_multi_use
    if !multi_use? && max_uses.present?
      errors.add(:max_uses, "can only be set for multi-use invites")
    end
  end
end
