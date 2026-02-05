# frozen_string_literal: true

# SafetyAuditLog tracks all safety-related events during sessions.
# These logs are NOT deleted with user data - they are anonymized and retained
# for compliance and safety system improvement purposes.
class SafetyAuditLog < ApplicationRecord
  belongs_to :journey_session

  # Event types that can be logged
  enum :event_type, {
    depth_threshold_crossed: 0,
    crisis_pattern_detected: 1,
    grounding_inserted: 2,
    pause_suggested: 3,
    integration_triggered: 4,
    crisis_protocol_activated: 5,
    user_dismissed_warning: 6,
    resource_displayed: 7,
    resource_clicked: 8,
    session_timeout: 9,
    iteration_limit_reached: 10,
    consent_withdrawn: 11  # GDPR: Session terminated due to consent withdrawal
  }, prefix: true

  # Validations
  validates :event_type, presence: true

  # Scopes
  scope :for_period, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :crisis_events, -> { where(event_type: [ :crisis_pattern_detected, :crisis_protocol_activated ]) }
  scope :intervention_events, -> { where(event_type: [ :grounding_inserted, :pause_suggested, :integration_triggered ]) }

  # Class methods

  # Anonymize all logs for a specific user (for GDPR deletion)
  # We keep the event structure but remove identifying trigger data
  def self.anonymize_for_user!(user_id)
    joins(:journey_session)
      .where(journey_sessions: { user_id: user_id })
      .update_all(trigger_data: { anonymized: true, anonymized_at: Time.current.iso8601 })
  end

  # Get aggregated metrics for a time period (for session review dashboard)
  def self.metrics_for_period(start_date, end_date)
    logs = for_period(start_date, end_date)

    {
      total_events: logs.count,
      crisis_activations: logs.event_type_crisis_protocol_activated.count,
      crisis_patterns_detected: logs.event_type_crisis_pattern_detected.count,
      grounding_insertions: logs.event_type_grounding_inserted.count,
      pauses_suggested: logs.event_type_pause_suggested.count,
      integrations_triggered: logs.event_type_integration_triggered.count,
      average_depth_at_intervention: logs.intervention_events.average(:depth_score_snapshot)&.round(3),
      resource_displays: logs.event_type_resource_displayed.count,
      resource_clicks: logs.event_type_resource_clicked.count
    }
  end

  # Instance methods

  # Check if this is a critical event requiring attention
  def critical?
    event_type_crisis_protocol_activated? || event_type_crisis_pattern_detected?
  end

  # Get a human-readable description of the event
  def description
    case event_type.to_sym
    when :depth_threshold_crossed
      "Depth score crossed threshold (#{depth_score_snapshot&.round(2)})"
    when :crisis_pattern_detected
      "Crisis language pattern detected"
    when :grounding_inserted
      "Grounding exercise inserted"
    when :pause_suggested
      "Pause suggested to user"
    when :integration_triggered
      "Early transition to integration phase"
    when :crisis_protocol_activated
      "Crisis protocol activated - resources displayed"
    when :user_dismissed_warning
      "User dismissed safety warning"
    when :resource_displayed
      "Crisis/support resources displayed"
    when :resource_clicked
      "User clicked on support resource"
    when :session_timeout
      "Session timed out"
    when :iteration_limit_reached
      "Maximum iteration limit reached"
    when :consent_withdrawn
      "Session terminated - consent withdrawn"
    else
      event_type.humanize
    end
  end
end
