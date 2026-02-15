# frozen_string_literal: true

# AdminUserInitializer creates an initial admin user from environment variables.
# This solves the bootstrap problem where you need an admin to create invites,
# but need an invite to create a user.
#
# Usage:
#   ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=secure123 bin/rails admin:create_initial
#
# Environment Variables:
#   ADMIN_EMAIL    - Required. Email address for the admin user.
#   ADMIN_PASSWORD - Required. Password (6-128 characters).
#   ADMIN_REGION   - Optional. Region for crisis resources (uk, us, eu, au, other). Default: uk
#
# Safety:
#   - Only runs when User.count == 0 (idempotent)
#   - Password is never logged
#   - Consents are marked with ip_address: "system-init" for audit trail
class AdminUserInitializer
  VALID_REGIONS = User.regions.keys.freeze
  MIN_PASSWORD_LENGTH = 6
  MAX_PASSWORD_LENGTH = 128

  class << self
    def call
      new.call
    end
  end

  def call
    return skip("Users already exist (count: #{User.count})") if User.any?
    return skip("ADMIN_EMAIL environment variable not set") if admin_email.blank?
    return skip("ADMIN_PASSWORD environment variable not set") if admin_password.blank?
    return skip("Password too short (minimum #{MIN_PASSWORD_LENGTH} characters)") if admin_password.length < MIN_PASSWORD_LENGTH
    return skip("Password too long (maximum #{MAX_PASSWORD_LENGTH} characters)") if admin_password.length > MAX_PASSWORD_LENGTH
    return skip("Invalid region '#{admin_region}' (valid: #{VALID_REGIONS.join(', ')})") unless valid_region?

    create_admin_user
  end

  private

  def admin_email
    ENV["ADMIN_EMAIL"]
  end

  def admin_password
    ENV["ADMIN_PASSWORD"]
  end

  def admin_region
    ENV.fetch("ADMIN_REGION", "uk")
  end

  def valid_region?
    VALID_REGIONS.include?(admin_region)
  end

  def skip(reason)
    Rails.logger.info("[AdminUserInitializer] Skipped: #{reason}")
    false
  end

  def create_admin_user
    ActiveRecord::Base.transaction do
      user = User.create!(
        email: admin_email,
        password: admin_password,
        password_confirmation: admin_password,
        region: admin_region,
        role: :admin
      )

      create_required_consents(user)

      Rails.logger.info("[AdminUserInitializer] Created admin user: #{admin_email} (region: #{admin_region})")
      true
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[AdminUserInitializer] Failed to create admin user: #{e.message}")
    false
  end

  def create_required_consents(user)
    Consent.required_consent_types.each do |consent_type|
      user.consents.create!(
        consent_type: consent_type,
        version: Consent.current_version_for(consent_type),
        given_at: Time.current,
        ip_address: "system-init"
      )
    end
  end
end
