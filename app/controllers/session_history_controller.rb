# frozen_string_literal: true

class SessionHistoryController < ApplicationController
  before_action :authenticate_user!
  before_action :set_session, only: [ :show, :destroy ]
  before_action :verify_owner, only: [ :show, :destroy ]

  def index
    @sessions = current_user.journey_sessions
                            .where(state: [ :completed, :paused, :abandoned ])
                            .order(created_at: :desc)
                            .limit(50)
  end

  def show
    @iterations = @session.session_iterations.order(:iteration_number)
  end

  def destroy
    @session.destroy!
    redirect_to session_history_index_path, notice: "Session deleted successfully."
  end

  private

  def set_session
    @session = JourneySession.find(params[:id])
  end

  def verify_owner
    unless @session.user == current_user
      redirect_to session_history_index_path, alert: "You don't have access to this session."
    end
  end
end
