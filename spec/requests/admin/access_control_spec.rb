# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Access Control", type: :request do
  include Devise::Test::IntegrationHelpers

  describe "session_reviewer role" do
    let(:user) { create(:user, :session_reviewer) }

    before { sign_in user }

    it "can access admin dashboard" do
      get admin_dashboard_path
      expect(response).to have_http_status(:success)
    end

    it "can access session reviews" do
      get admin_session_reviews_path
      expect(response).to have_http_status(:success)
    end

    it "can access safety metrics" do
      get admin_safety_metrics_path
      expect(response).to have_http_status(:success)
    end

    it "cannot access invites" do
      get admin_invites_path
      # Invites controller redirects non-admin users to the main dashboard
      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe "admin role" do
    let(:user) { create(:user, :admin) }

    before { sign_in user }

    it "can access admin dashboard" do
      get admin_dashboard_path
      expect(response).to have_http_status(:success)
    end

    it "can access invites" do
      get admin_invites_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "regular user" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "cannot access admin dashboard" do
      get admin_dashboard_path
      expect(response).to redirect_to(dashboard_path)
    end

    it "cannot access session reviews" do
      get admin_session_reviews_path
      expect(response).to redirect_to(dashboard_path)
    end
  end
end
