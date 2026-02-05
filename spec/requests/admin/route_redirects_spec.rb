# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Route Redirects", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :session_reviewer) }

  before { sign_in user }

  describe "legacy clinical_reviews routes" do
    it "redirects /admin/clinical_reviews to /admin/session_reviews" do
      get "/admin/clinical_reviews"
      expect(response).to redirect_to("/admin/session_reviews")
    end

    it "redirects /admin/clinical_reviews/:id to /admin/session_reviews/:id" do
      get "/admin/clinical_reviews/123"
      expect(response).to redirect_to("/admin/session_reviews/123")
    end
  end
end
