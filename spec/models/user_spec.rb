# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "role enum" do
    it "defines user, session_reviewer, and admin roles" do
      expect(User.roles.keys).to match_array(%w[user session_reviewer admin])
    end

    it "defaults to user role" do
      user = User.new
      expect(user.role).to eq("user")
    end

    it "uses correct integer mappings" do
      expect(User.roles["user"]).to eq(0)
      expect(User.roles["session_reviewer"]).to eq(1)
      expect(User.roles["admin"]).to eq(2)
    end
  end

  describe "#can_review_sessions?" do
    it "returns true for session_reviewer" do
      user = build(:user, :session_reviewer)
      expect(user.can_review_sessions?).to be true
    end

    it "returns true for admin" do
      user = build(:user, :admin)
      expect(user.can_review_sessions?).to be true
    end

    it "returns false for regular user" do
      user = build(:user)
      expect(user.can_review_sessions?).to be false
    end
  end

  describe "role helper methods" do
    it "responds to role_session_reviewer?" do
      user = build(:user, :session_reviewer)
      expect(user.role_session_reviewer?).to be true
    end

    it "responds to role_admin?" do
      user = build(:user, :admin)
      expect(user.role_admin?).to be true
    end

    it "responds to role_user?" do
      user = build(:user)
      expect(user.role_user?).to be true
    end
  end
end
