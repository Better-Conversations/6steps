# frozen_string_literal: true

module Admin
  class SafetyMetricsController < BaseController
    def index
      @period = params[:period] || "30_days"

      @metrics = {
        total_sessions: sessions_in_period.count,
        completed_sessions: sessions_in_period.where(state: :completed).count,
        paused_sessions: sessions_in_period.where(state: :paused).count,
        abandoned_sessions: sessions_in_period.where(state: :abandoned).count,
        crisis_activations: audit_logs_in_period.where(event_type: :crisis_detected).count,
        grounding_insertions: audit_logs_in_period.where(event_type: :grounding_inserted).count,
        pause_suggestions: audit_logs_in_period.where(event_type: :pause_suggested).count,
        average_depth_score: sessions_in_period.average(:current_depth_score)&.round(3) || 0,
        average_iterations: sessions_in_period.average(:iteration_count)&.round(1) || 0
      }

      @completion_rate = calculate_completion_rate
      @depth_over_time = calculate_depth_over_time
    end

    private

    def period_start_date
      case @period
      when "7_days" then 7.days.ago
      when "30_days" then 30.days.ago
      when "90_days" then 90.days.ago
      when "all_time" then 10.years.ago
      else 30.days.ago
      end
    end

    def sessions_in_period
      JourneySession.where("created_at >= ?", period_start_date)
    end

    def audit_logs_in_period
      SafetyAuditLog.where("created_at >= ?", period_start_date)
    end

    def calculate_completion_rate
      total = sessions_in_period.count
      return 0 if total.zero?

      completed = sessions_in_period.where(state: :completed).count
      (completed.to_f / total * 100).round(1)
    end

    def calculate_depth_over_time
      # Group sessions by date and calculate average depth score
      sessions_in_period
        .group("DATE(created_at)")
        .order("DATE(created_at)")
        .average(:current_depth_score)
        .transform_keys { |date| date.to_date }
        .transform_values { |avg| avg&.round(3) }
    end
  end
end
