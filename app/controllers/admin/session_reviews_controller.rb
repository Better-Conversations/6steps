# frozen_string_literal: true

module Admin
  class SessionReviewsController < BaseController
    def index
      @sessions = JourneySession
        .joins(:safety_audit_logs)
        .where(safety_audit_logs: { event_type: [ :crisis_pattern_detected, :crisis_protocol_activated, :depth_threshold_crossed ] })
        .distinct
        .order(created_at: :desc)
        .limit(50)
    end

    def show
      @session = JourneySession.find(params[:id])
      @audit_logs = @session.safety_audit_logs.order(:created_at)
      @iterations = @session.session_iterations.order(:iteration_number)
    end
  end
end
