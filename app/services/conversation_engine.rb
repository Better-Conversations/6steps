# frozen_string_literal: true

# ConversationEngine orchestrates the entire session flow.
# It coordinates between SafetyMonitor, QuestionGenerator, and session state management.
class ConversationEngine
  # Response types that can be returned
  ConversationResponse = Struct.new(:type, :question, :state, :iteration, :show_resources, :data, keyword_init: true)
  GroundingResponse = Struct.new(:type, :exercise, :continue_option, :data, keyword_init: true)
  PauseResponse = Struct.new(:type, :message, :options, :data, keyword_init: true)
  IntegrationResponse = Struct.new(:type, :summary, :closing_question, :data, keyword_init: true)
  CrisisResponse = Struct.new(:type, :resources, :message, :data, keyword_init: true)

  attr_reader :session, :user

  def initialize(session)
    @session = session
    @user = session.user
    @question_generator = QuestionGenerator.new(session)
    @safety_monitor = SafetyMonitor.new(session)
  end

  # Process a user response and return the appropriate next action
  def process_response(user_input)
    # If we're in integration phase, handle the integration response
    # without running full safety checks (the session is wrapping up)
    if @session.state_integration?
      return process_integration_response(user_input)
    end

    # 1. Safety check first - this is ALWAYS the first step
    safety_result = @safety_monitor.assess(user_input)

    # 2. Handle crisis immediately (only for explicit crisis language)
    if safety_result.crisis?
      return handle_crisis(safety_result)
    end

    # 3. Handle other interventions
    if safety_result.needs_intervention?
      return handle_intervention(safety_result, user_input)
    end

    # 4. Store the iteration
    store_iteration(user_input, safety_result.depth_score)

    # 5. Check containment limits
    if @session.at_iteration_limit? || @session.at_time_limit?
      return transition_to_integration
    end

    # 6. Check for soft time limit warning
    if @session.should_warn_time_limit?
      @session.mark_time_warned!
      log_safety_event(:session_timeout, safety_result)
    end

    # 7. Generate next clean question
    next_question = @question_generator.generate_next(user_input)

    ConversationResponse.new(
      type: :continue,
      question: next_question,
      state: @session.state,
      iteration: @session.iteration_count,
      show_resources: safety_result.amber_or_higher?,
      data: {
        safety_level: safety_result.safety_level,
        time_warned: @session.soft_time_limit_warned
      }
    )
  end

  # Process the final integration response and complete the session
  def process_integration_response(user_input)
    # Guard against double-submission - if already completed, just return the completion response
    if @session.state_completed?
      return IntegrationResponse.new(
        type: :completed,
        summary: @session.export_summary,
        closing_question: nil,
        data: { session_id: @session.id, already_completed: true }
      )
    end

    # Still check for explicit crisis language even in integration
    safety_result = @safety_monitor.assess(user_input)
    if safety_result.crisis?
      return handle_crisis(safety_result)
    end

    # Store the integration insight only if we haven't already stored one
    # (prevents duplicate entries on double-submit)
    unless @session.session_iterations.exists?(space_explored: "integration")
      # Use current iteration_count for the integration iteration
      # This is valid since integration is space_explored: "integration", not a regular iteration
      integration_iteration_number = [ @session.iteration_count, 1 ].max
      @session.session_iterations.create!(
        iteration_number: integration_iteration_number,
        user_response: user_input,
        question_asked: @question_generator.integration_question,
        space_explored: "integration",
        depth_score_at_end: safety_result.depth_score,
        safety_intervention: nil,
        reflected_words: nil
      )
    end

    # Complete the session
    @session.complete!

    IntegrationResponse.new(
      type: :completed,
      summary: @session.export_summary,
      closing_question: @question_generator.closing_question,
      data: {
        session_id: @session.id,
        integration_insight: user_input
      }
    )
  end

  # Start a new session with a selected space
  def start_with_space(space)
    @session.update!(current_space: space)
    @session.select_space!

    first_question = @question_generator.first_question_for_space(space)

    # Save the first question to session so the view can display it
    @session.update!(pending_question: first_question)

    ConversationResponse.new(
      type: :first_question,
      question: first_question,
      state: @session.state,
      iteration: 0,
      show_resources: false,
      data: { space: space }
    )
  end

  # Pause the current session
  def pause_session
    @session.pause!

    log_safety_event(:pause_suggested, nil, response_taken: "user_paused")

    PauseResponse.new(
      type: :paused,
      message: I18n.t("sessions.paused_message", default: "Session paused. Take all the time you need."),
      options: [ :resume, :end_session, :show_resources ],
      data: { can_resume: @session.can_continue_iteration? }
    )
  end

  # Resume a paused session
  def resume_session(to_integration: false)
    if to_integration || !@session.can_continue_iteration?
      @session.resume_to_integration!
      return transition_to_integration
    end

    @session.resume!
    last_question = @session.pending_question || @question_generator.generate_next

    ConversationResponse.new(
      type: :resumed,
      question: last_question,
      state: @session.state,
      iteration: @session.iteration_count,
      show_resources: @session.current_depth_score >= 0.3,
      data: {}
    )
  end

  # End the session normally
  def end_session
    @session.complete! if @session.may_complete?

    IntegrationResponse.new(
      type: :completed,
      summary: @session.export_summary,
      closing_question: nil,
      data: { session_id: @session.id }
    )
  end

  # Abandon the session (user explicitly exits)
  def abandon_session
    @session.abandon!

    { type: :abandoned, session_id: @session.id }
  end

  private

  def handle_crisis(safety_result)
    @session.pause!

    log_safety_event(:crisis_protocol_activated, safety_result)
    log_safety_event(:resource_displayed, safety_result)

    resources = CrisisResources.crisis_modal_content(@user.region)

    CrisisResponse.new(
      type: :crisis,
      resources: resources,
      message: I18n.t("sessions.crisis_message",
                      default: "Here are some resources you might find useful."),
      data: {
        region: @user.region,
        session_paused: true
      }
    )
  end

  def handle_intervention(safety_result, user_input)
    case safety_result.intervention_type
    when :grounding_needed
      handle_grounding(safety_result)
    when :pause_suggested
      handle_pause_suggestion(safety_result, user_input)
    when :integration_needed
      handle_early_integration(safety_result, user_input)
    end
  end

  def handle_grounding(safety_result)
    @session.record_grounding!
    log_safety_event(:grounding_inserted, safety_result)

    exercise = CrisisResources.random_grounding_exercise

    GroundingResponse.new(
      type: :grounding,
      exercise: exercise,
      continue_option: true,
      data: {
        depth_score: safety_result.depth_score,
        safety_level: safety_result.safety_level
      }
    )
  end

  def handle_pause_suggestion(safety_result, user_input)
    log_safety_event(:pause_suggested, safety_result)
    log_safety_event(:resource_displayed, safety_result)

    # Store the iteration even though we're suggesting a pause
    store_iteration(user_input, safety_result.depth_score)

    # Generate the next question so it's ready when user continues
    # This ensures pending_question is updated for the next iteration
    @question_generator.generate_next(user_input) unless @session.at_iteration_limit?

    PauseResponse.new(
      type: :pause_suggested,
      message: I18n.t("sessions.pause_suggestion",
                      default: "Would you like to take a moment before continuing?"),
      options: [ :continue_gently, :pause, :show_resources ],
      data: {
        depth_score: safety_result.depth_score,
        resources_available: true
      }
    )
  end

  def handle_early_integration(safety_result, user_input)
    log_safety_event(:integration_triggered, safety_result)

    # Store the iteration
    store_iteration(user_input, safety_result.depth_score, safety_intervention: "early_integration")

    # Transition to integration
    @session.begin_integration!

    transition_to_integration
  end

  def transition_to_integration
    @session.begin_integration! unless @session.state_integration?

    if @session.at_iteration_limit?
      log_safety_event(:iteration_limit_reached, nil)
    end

    summary = generate_session_summary

    IntegrationResponse.new(
      type: :integration,
      summary: summary,
      closing_question: @question_generator.integration_question,
      data: {
        spaces_explored: @session.spaces_explored,
        iterations: @session.iteration_count
      }
    )
  end

  def store_iteration(user_input, depth_score, safety_intervention: nil)
    @session.session_iterations.create!(
      iteration_number: @session.iteration_count + 1,
      user_response: user_input,
      question_asked: @session.pending_question,
      space_explored: @session.current_space,
      depth_score_at_end: depth_score,
      safety_intervention: safety_intervention,
      reflected_words: @session.reflected_words_cache
    )

    @session.advance_iteration!(depth_score)
  end

  def log_safety_event(event_type, safety_result, response_taken: nil)
    @session.safety_audit_logs.create!(
      event_type: event_type,
      trigger_data: safety_result&.anonymized_triggers || {},
      depth_score_snapshot: safety_result&.depth_score || @session.current_depth_score,
      response_taken: response_taken || event_type.to_s
    )
  end

  def generate_session_summary
    spaces = @session.spaces_explored

    {
      started_at: @session.started_at,
      duration_minutes: @session.duration_minutes,
      spaces_explored: spaces,
      iterations_completed: @session.iteration_count,
      peak_depth_score: @session.peak_depth_score,
      had_interventions: @session.had_safety_interventions?
    }
  end
end
