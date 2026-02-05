# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def show
      @total_sessions = JourneySession.count
      @completed_sessions = JourneySession.where(state: :completed).count
      @crisis_activations = SafetyAuditLog.where(event_type: :crisis_detected).count
      @grounding_insertions = SafetyAuditLog.where(event_type: :grounding_inserted).count

      @recent_flagged_sessions = JourneySession
        .joins(:safety_audit_logs)
        .where(safety_audit_logs: { event_type: [ :crisis_detected, :elevated_depth ] })
        .distinct
        .order(created_at: :desc)
        .limit(10)

      @depth_distribution = calculate_depth_distribution
    end

    private

    def calculate_depth_distribution
      {
        green: JourneySession.where("current_depth_score < 0.3").count,
        amber: JourneySession.where("current_depth_score >= 0.3 AND current_depth_score < 0.5").count,
        amber_red: JourneySession.where("current_depth_score >= 0.5 AND current_depth_score < 0.7").count,
        red: JourneySession.where("current_depth_score >= 0.7 AND current_depth_score < 0.9").count,
        deep_red: JourneySession.where("current_depth_score >= 0.9").count
      }
    end
  end
end
