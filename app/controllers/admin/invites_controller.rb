# frozen_string_literal: true

module Admin
  class InvitesController < BaseController
    before_action :require_admin
    before_action :set_invite, only: [ :show, :destroy, :revoke ]

    def index
      @invites = Invite.includes(:created_by, :used_by).recent.limit(100)
      @valid_invites = Invite.valid.count
      @used_invites = Invite.used.count
      @expired_invites = Invite.expired.unused.count
    end

    def show
    end

    def new
      @invite = Invite.new
    end

    def create
      @invite = Invite.new(invite_params)
      @invite.created_by = current_user
      @invite.expires_at = calculate_expiry

      if @invite.save
        redirect_to admin_invite_path(@invite), notice: "Invite created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      if @invite.used?
        redirect_to admin_invites_path, alert: "Cannot delete an invite that has been used."
      else
        @invite.destroy!
        redirect_to admin_invites_path, notice: "Invite deleted."
      end
    end

    # Revoke an invite (mark as expired without deleting for audit trail)
    def revoke
      if !@invite.multi_use? && @invite.used?
        # Single-use invites cannot be revoked once used
        redirect_to admin_invites_path, alert: "Cannot revoke an invite that has been used."
      elsif @invite.expired?
        redirect_to admin_invites_path, alert: "Invite has already expired."
      elsif @invite.max_uses_reached?
        redirect_to admin_invites_path, alert: "Invite has already reached its usage limit."
      else
        # Multi-use invites can be revoked even after partial use
        @invite.update!(expires_at: Time.current)
        redirect_to admin_invites_path, notice: "Invite revoked."
      end
    end

    private

    def require_admin
      unless current_user.role_admin?
        redirect_to dashboard_path, alert: "You don't have permission to manage invites."
      end
    end

    def set_invite
      @invite = Invite.find(params[:id])
    end

    def invite_params
      params.require(:invite).permit(:email, :notes, :multi_use, :max_uses)
    end

    def calculate_expiry
      days = params.dig(:invite, :expires_in_days).to_i
      days = Invite::DEFAULT_EXPIRY_DAYS if days <= 0 || days > 30
      days.days.from_now
    end
  end
end
