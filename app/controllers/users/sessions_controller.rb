# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # GET /resource/sign_in
  def new
    super
  end

  # POST /resource/sign_in
  def create
    super
  end

  # DELETE /resource/sign_out
  def destroy
    super
  end

  protected

  # Redirect to dashboard after sign in
  def after_sign_in_path_for(resource)
    dashboard_path
  end

  # Redirect to home after sign out
  def after_sign_out_path_for(resource_or_scope)
    root_path
  end
end
