# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @active_session = current_user.journey_sessions.active.first
    @recent_sessions = current_user.journey_sessions
                                   .where.not(state: :welcome)
                                   .order(created_at: :desc)
                                   .limit(5)
    @has_required_consents = current_user.can_start_session?
    @missing_consents = missing_consent_types
  end

  private

  def missing_consent_types
    Consent.required_consent_types.reject { |type| current_user.active_consent_for?(type) }
  end
end
