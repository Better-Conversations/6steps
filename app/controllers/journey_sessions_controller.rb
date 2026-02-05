# frozen_string_literal: true

class JourneySessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_consents, only: [ :new, :create ]
  before_action :set_journey_session, only: [ :show, :respond, :pause, :resume, :complete, :export_pdf ]
  before_action :verify_session_owner, only: [ :show, :respond, :pause, :resume, :complete, :export_pdf ]

  def new
    # Check for existing active session
    @active_session = current_user.journey_sessions.active.first
    if @active_session
      redirect_to journey_session_path(@active_session), notice: "You have an active session in progress."
      return
    end

    @journey_session = current_user.journey_sessions.build
    @spaces = QuestionGenerator::SPACE_DESCRIPTIONS
    @first_time = current_user.first_time_user?
  end

  def create
    space = params[:space]

    unless QuestionGenerator::SPACE_DESCRIPTIONS.key?(space&.to_sym)
      redirect_to new_journey_session_path, alert: "Please select a valid space."
      return
    end

    @journey_session = current_user.journey_sessions.create!(
      state: :welcome,
      started_at: Time.current
    )

    # Transition through states and start session with selected space
    @journey_session.give_consent!

    engine = ConversationEngine.new(@journey_session)
    engine.start_with_space(space)

    redirect_to journey_session_path(@journey_session)
  end

  def show
    @engine = ConversationEngine.new(@journey_session)
    @spaces = QuestionGenerator::SPACE_DESCRIPTIONS
    @elapsed_time = @journey_session.started_at ? Time.current - @journey_session.started_at : 0

    # Check if session should be timed out
    if @journey_session.at_time_limit? && !@journey_session.state_completed?
      if @journey_session.may_complete?
        @journey_session.complete!
        redirect_to session_history_path(@journey_session), notice: "Your session has reached the 30-minute time limit and has been completed."
      else
        # If we can't complete, abandon instead to prevent redirect loops
        @journey_session.abandon! if @journey_session.may_abandon?
        redirect_to dashboard_path, alert: "Your session has timed out."
      end
      nil
    end
  end

  def respond
    user_response = params[:response]&.strip

    if user_response.blank?
      redirect_to journey_session_path(@journey_session), alert: "Please enter a response."
      return
    end

    engine = ConversationEngine.new(@journey_session)
    @response = engine.process_response(user_response)

    # Reload to get updated iteration_count for turbo stream updates
    @journey_session.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to journey_session_path(@journey_session) }
    end
  end

  def pause
    if @journey_session.may_pause?
      @journey_session.pause!
      redirect_to dashboard_path, notice: "Your session has been paused. You can resume it anytime."
    else
      redirect_to journey_session_path(@journey_session), alert: "This session cannot be paused."
    end
  end

  def resume
    if @journey_session.may_resume?
      @journey_session.resume!
      redirect_to journey_session_path(@journey_session), notice: "Welcome back! Let's continue your reflection."
    else
      redirect_to journey_session_path(@journey_session), alert: "This session cannot be resumed."
    end
  end

  def complete
    if @journey_session.may_complete?
      @journey_session.complete!
      redirect_to session_history_path(@journey_session), notice: "Session completed. Thank you for your reflection."
    else
      redirect_to journey_session_path(@journey_session), alert: "This session cannot be completed."
    end
  end

  def export_pdf
    unless @journey_session.state_completed?
      redirect_to journey_session_path(@journey_session), alert: "Only completed sessions can be exported."
      return
    end

    pdf = SessionPdfExporter.new(@journey_session).generate
    send_data pdf.render,
              filename: "six-steps-session-#{@journey_session.id}-#{Date.current}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  private

  def require_consents
    unless current_user.can_start_session?
      redirect_to consents_path, alert: "Please provide required consents before starting a session."
    end
  end

  def set_journey_session
    @journey_session = JourneySession.find(params[:id])
  end

  def verify_session_owner
    unless @journey_session.user == current_user
      redirect_to dashboard_path, alert: "You don't have access to this session."
    end
  end
end
