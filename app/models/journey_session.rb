# frozen_string_literal: true

# JourneySession represents a single reflection session using the Six Spaces approach.
# Each session has a maximum of 6 iterations and 30 minutes duration.
class JourneySession < ApplicationRecord
  include AASM

  has_paper_trail

  # Encrypted fields for sensitive content
  encrypts :current_space
  encrypts :session_summary
  encrypts :pending_question
  encrypts :reflected_words_cache

  # Associations
  belongs_to :user
  has_many :session_iterations, dependent: :destroy
  has_many :safety_audit_logs, dependent: :destroy

  # Constants
  MAX_ITERATIONS = 6
  SOFT_TIME_LIMIT_MINUTES = 15
  HARD_TIME_LIMIT_MINUTES = 30

  SPACES = %w[here there before after inside outside].freeze

  # Validations
  validates :iteration_count, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: MAX_ITERATIONS
  }
  validates :current_depth_score, numericality: {
    greater_than_or_equal_to: 0.0,
    less_than_or_equal_to: 1.0
  }
  validates :current_space, inclusion: { in: SPACES }, allow_nil: true

  # Scopes
  scope :active, -> { where(state: [ :welcome, :space_selection, :emergence_cycle ]) }
  scope :completed_sessions, -> { where(state: :completed) }
  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_safety_events, -> { joins(:safety_audit_logs).distinct }

  # State machine using AASM
  aasm column: :state, enum: true do
    state :welcome, initial: true
    state :space_selection
    state :emergence_cycle
    state :integration
    state :paused
    state :completed
    state :abandoned

    # Normal flow transitions
    event :give_consent do
      transitions from: :welcome, to: :space_selection
    end

    event :select_space do
      transitions from: :space_selection, to: :emergence_cycle, after: :record_session_start
    end

    event :continue_iteration do
      transitions from: :emergence_cycle, to: :emergence_cycle,
                  guard: :can_continue_iteration?
    end

    event :begin_integration do
      transitions from: :emergence_cycle, to: :integration
    end

    # Safety transitions
    event :pause do
      transitions from: [ :emergence_cycle, :integration ], to: :paused
    end

    event :resume do
      transitions from: :paused, to: :emergence_cycle, guard: :can_continue_iteration?
      transitions from: :paused, to: :integration
    end

    event :resume_to_integration do
      transitions from: :paused, to: :integration
    end

    # Completion transitions
    event :complete do
      transitions from: [ :emergence_cycle, :integration, :paused ], to: :completed, after: :record_completion
    end

    event :abandon do
      transitions from: [ :welcome, :space_selection, :emergence_cycle, :integration, :paused ],
                  to: :abandoned
    end
  end

  # Enum for state (used by AASM)
  enum :state, {
    welcome: 0,
    space_selection: 1,
    emergence_cycle: 2,
    integration: 3,
    paused: 4,
    completed: 5,
    abandoned: 6
  }, prefix: true

  # Instance methods

  # Calculate session duration in minutes
  def duration_minutes
    return 0 unless started_at

    ((Time.current - started_at) / 60).round
  end

  # Check if session has reached iteration limit
  def at_iteration_limit?
    iteration_count >= MAX_ITERATIONS
  end

  # Check if session has reached hard time limit
  def at_time_limit?
    duration_minutes >= HARD_TIME_LIMIT_MINUTES
  end

  # Check if session should show soft time warning
  def should_warn_time_limit?
    !soft_time_limit_warned && duration_minutes >= SOFT_TIME_LIMIT_MINUTES
  end

  # Check if session can continue with another iteration
  def can_continue_iteration?
    !at_iteration_limit? && !at_time_limit?
  end

  # Increment iteration count and update depth score
  def advance_iteration!(new_depth_score)
    increment!(:iteration_count)
    update!(current_depth_score: new_depth_score)
  end

  # Record a grounding intervention
  def record_grounding!
    increment!(:grounding_insertions_count)
  end

  # Mark soft time limit as warned
  def mark_time_warned!
    update!(soft_time_limit_warned: true)
  end

  # Get spaces explored in this session
  def spaces_explored
    session_iterations.pluck(:space_explored).compact.uniq
  end

  # Get the integration insight (last user response in integration phase)
  def integration_insight
    session_iterations.where(space_explored: "integration").last&.user_response
  end

  # Check if session had any safety interventions
  def had_safety_interventions?
    safety_audit_logs.any?
  end

  # Get the highest depth score reached
  def peak_depth_score
    session_iterations.maximum(:depth_score_at_end) || current_depth_score
  end

  # Check if this session is still active
  def active?
    %w[welcome space_selection emergence_cycle].include?(state)
  end

  # Generate a summary for export
  def export_summary
    {
      date: started_at&.to_date,
      duration_minutes: duration_minutes,
      spaces_explored: spaces_explored,
      iterations_completed: iteration_count,
      reflected_words: session_iterations.pluck(:reflected_words).compact,
      integration_insight: integration_insight,
      resources_shown: safety_audit_logs.event_type_resource_displayed.any?
    }
  end

  private

  def record_session_start
    update!(started_at: Time.current)
  end

  def record_completion
    # Generate session summary if not already present
    return if session_summary.present?

    summary = "Session completed on #{Time.current.strftime('%B %d, %Y')}. "
    summary += "Explored #{spaces_explored.count} space(s). "
    summary += "Completed #{iteration_count} reflection(s)."

    update!(session_summary: summary)
  end
end
