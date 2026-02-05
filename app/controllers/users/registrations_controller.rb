# frozen_string_literal: true

# ============================================================================
# COMPLIANCE WARNING - GDPR DATA SUBJECT RIGHTS
# ============================================================================
# This controller handles GDPR Articles 15, 17, and 20:
# - export_data: Right to data portability (Article 20)
# - destroy: Right to erasure (Article 17)
#
# Modifications require DPO review. See COMPLIANCE.md Section 4.
# ============================================================================

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [ :create ]
  before_action :configure_account_update_params, only: [ :update ]
  before_action :require_valid_invite, only: [ :new, :create ]

  # GET /resource/sign_up
  def new
    @invite = Invite.find_valid(params[:invite])
    super
  end

  # POST /resource
  def create
    @invite = Invite.find_valid(params[:invite_token])

    # Check email restriction
    if @invite&.email_restricted? && !@invite.valid_for_email?(sign_up_params[:email])
      flash[:alert] = "This invite is restricted to a specific email address."
      redirect_to new_user_registration_path(invite: params[:invite_token])
      return
    end

    super do |resource|
      if resource.persisted? && @invite
        @invite.mark_used!(resource)
      end
    end
  end

  # GET /resource/edit
  def edit
    super
  end

  # PUT /resource
  def update
    super
  end

  # DELETE /resource
  def destroy
    super
  end

  # GET /users/export_data
  # GDPR: Right to data portability (Article 20)
  # Returns all personal data in a structured, commonly used format
  def export_data
    @user = current_user
    user_data = {
      exported_at: Time.current.iso8601,
      gdpr_article: "Article 20 - Right to data portability",
      account: {
        email: @user.email,
        region: @user.region,
        role: @user.role,
        created_at: @user.created_at.iso8601,
        timezone: @user.timezone
      },
      consents: @user.consents.order(:created_at).map do |consent|
        {
          type: consent.consent_type,
          version: consent.version,
          given_at: consent.given_at&.iso8601,
          withdrawn_at: consent.withdrawn_at&.iso8601,
          active: consent.active?
        }
      end,
      sessions: @user.journey_sessions.order(:created_at).map do |session|
        {
          id: session.id,
          state: session.state,
          spaces_explored: session.spaces_explored,
          iteration_count: session.iteration_count,
          started_at: session.started_at&.iso8601,
          created_at: session.created_at.iso8601,
          session_summary: session.session_summary,
          iterations: session.session_iterations.order(:iteration_number).map do |iteration|
            iteration.export_data
          end
        }
      end,
      data_retention_note: "Session content is automatically redacted after 30 days. " \
                           "Redacted content is marked as such in the export."
    }

    respond_to do |format|
      format.json do
        response.headers["Content-Disposition"] = "attachment; filename=six-steps-data-export-#{Date.current}.json"
        render json: JSON.pretty_generate(user_data)
      end
      format.html { redirect_to edit_user_registration_path, notice: "Use JSON format to download your data." }
    end
  end

  protected

  # Require a valid invite to register
  def require_valid_invite
    token = params[:invite] || params[:invite_token]
    @invite = Invite.find_valid(token)

    unless @invite
      render "users/registrations/invite_required", status: :forbidden and return
    end
  end

  # Permit region and invite_token during sign up
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :region, :invite_token ])
  end

  # Permit region during account update
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [ :region, :timezone ])
  end

  # Redirect to dashboard after sign up
  def after_sign_up_path_for(resource)
    dashboard_path
  end

  # Redirect to dashboard after update
  def after_update_path_for(resource)
    dashboard_path
  end
end
