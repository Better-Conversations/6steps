# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_session_review_access

    layout "admin"

    private

    def require_session_review_access
      unless current_user.can_review_sessions?
        redirect_to dashboard_path, alert: "You don't have permission to access this area."
      end
    end
  end
end
