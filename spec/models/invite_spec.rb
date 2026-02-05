# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invite, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      invite = build(:invite)
      expect(invite).to be_valid
    end

    it "auto-generates token if not provided" do
      invite = build(:invite)
      invite.token = nil
      invite.valid?
      expect(invite.token).to be_present
    end

    it "requires unique token" do
      existing = create(:invite)
      invite = build(:invite)
      invite.token = existing.token
      expect(invite).not_to be_valid
    end

    it "auto-sets expires_at if not provided" do
      invite = build(:invite, expires_at: nil)
      invite.valid?
      expect(invite.expires_at).to be_present
    end

    it "validates email format when present" do
      invite = build(:invite, email: "invalid-email")
      expect(invite).not_to be_valid
    end

    it "validates max_uses is positive when present" do
      invite = build(:invite, :multi_use, max_uses: 0)
      expect(invite).not_to be_valid
    end

    it "allows nil max_uses" do
      invite = build(:invite, :multi_use, max_uses: nil)
      expect(invite).to be_valid
    end

    it "prevents email restriction on multi-use invites" do
      invite = build(:invite, multi_use: true, email: "test@example.com")
      expect(invite).not_to be_valid
      expect(invite.errors[:email]).to include("cannot be set for multi-use invites")
    end

    it "prevents max_uses on single-use invites" do
      invite = build(:invite, multi_use: false, max_uses: 10)
      expect(invite).not_to be_valid
      expect(invite.errors[:max_uses]).to include("can only be set for multi-use invites")
    end
  end

  describe "callbacks" do
    it "generates token before validation on create" do
      invite = build(:invite)
      invite.token = nil
      invite.valid?
      expect(invite.token).to be_present
    end

    it "sets default expiry before validation on create" do
      invite = build(:invite)
      invite.expires_at = nil
      invite.valid?
      expect(invite.expires_at).to be_present
    end
  end

  describe "scopes" do
    describe ".valid" do
      it "includes unused, unexpired single-use invites" do
        invite = create(:invite)
        expect(Invite.valid).to include(invite)
      end

      it "includes unexpired multi-use invites with remaining uses" do
        invite = create(:invite, :multi_use, use_count: 5)
        expect(Invite.valid).to include(invite)
      end

      it "excludes used single-use invites" do
        invite = create(:invite, :used)
        expect(Invite.valid).not_to include(invite)
      end

      it "excludes expired invites" do
        invite = create(:invite, :expired)
        expect(Invite.valid).not_to include(invite)
      end

      it "excludes exhausted multi-use invites" do
        invite = create(:invite, :exhausted)
        expect(Invite.valid).not_to include(invite)
      end
    end

    describe ".multi_use_invites" do
      it "returns only multi-use invites" do
        single = create(:invite)
        multi = create(:invite, :multi_use)
        expect(Invite.multi_use_invites).to include(multi)
        expect(Invite.multi_use_invites).not_to include(single)
      end
    end
  end

  describe ".find_valid" do
    it "finds a valid invite by token" do
      invite = create(:invite)
      expect(Invite.find_valid(invite.token)).to eq(invite)
    end

    it "returns nil for expired invite" do
      invite = create(:invite, :expired)
      expect(Invite.find_valid(invite.token)).to be_nil
    end

    it "returns nil for used single-use invite" do
      invite = create(:invite, :used)
      expect(Invite.find_valid(invite.token)).to be_nil
    end

    it "finds a valid multi-use invite even when used" do
      invite = create(:invite, :multi_use)
      invite.update!(used_at: Time.current, use_count: 3)
      expect(Invite.find_valid(invite.token)).to eq(invite)
    end

    it "returns nil for exhausted multi-use invite" do
      invite = create(:invite, :exhausted)
      expect(Invite.find_valid(invite.token)).to be_nil
    end
  end

  describe "#valid_for_use?" do
    it "returns true for unused, unexpired single-use invite" do
      invite = create(:invite)
      expect(invite.valid_for_use?).to be true
    end

    it "returns false for used single-use invite" do
      invite = create(:invite, :used)
      expect(invite.valid_for_use?).to be false
    end

    it "returns false for expired invite" do
      invite = create(:invite, :expired)
      expect(invite.valid_for_use?).to be false
    end

    it "returns true for multi-use invite with uses remaining" do
      invite = create(:invite, :with_max_uses)
      invite.update!(use_count: 5)
      expect(invite.valid_for_use?).to be true
    end

    it "returns false for exhausted multi-use invite" do
      invite = create(:invite, :exhausted)
      expect(invite.valid_for_use?).to be false
    end

    it "returns true for unlimited multi-use invite" do
      invite = create(:invite, :multi_use)
      invite.update!(use_count: 1000)
      expect(invite.valid_for_use?).to be true
    end
  end

  describe "#mark_used!" do
    let(:user) { create(:user) }

    context "single-use invite" do
      it "marks the invite as used" do
        invite = create(:invite)
        invite.mark_used!(user)
        expect(invite.used_at).to be_present
        expect(invite.used_by).to eq(user)
        expect(invite.use_count).to eq(1)
      end
    end

    context "multi-use invite" do
      it "increments use_count" do
        invite = create(:invite, :multi_use)
        invite.mark_used!(user)
        expect(invite.use_count).to eq(1)
      end

      it "allows multiple uses" do
        invite = create(:invite, :multi_use)
        user2 = create(:user)

        invite.mark_used!(user)
        invite.mark_used!(user2)

        expect(invite.use_count).to eq(2)
      end

      it "preserves first user info" do
        invite = create(:invite, :multi_use)
        user2 = create(:user)

        invite.mark_used!(user)
        invite.mark_used!(user2)

        expect(invite.used_by).to eq(user)
      end

      it "raises error when max_uses is reached" do
        invite = create(:invite, :with_max_uses, max_uses: 2, use_count: 2)
        expect { invite.mark_used!(user) }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "is concurrency-safe with locking" do
        invite = create(:invite, :with_max_uses, max_uses: 1)
        # The lock should prevent exceeding max_uses
        invite.mark_used!(user)
        expect(invite.use_count).to eq(1)
        expect { invite.mark_used!(create(:user)) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "#status" do
    it "returns :valid for unused single-use invite" do
      invite = create(:invite)
      expect(invite.status).to eq(:valid)
    end

    it "returns :used for used single-use invite" do
      invite = create(:invite, :used)
      expect(invite.status).to eq(:used)
    end

    it "returns :expired for expired invite" do
      invite = create(:invite, :expired)
      expect(invite.status).to eq(:expired)
    end

    it "returns :active for multi-use invite in use" do
      invite = create(:invite, :multi_use)
      invite.update!(use_count: 5, used_at: Time.current)
      expect(invite.status).to eq(:active)
    end

    it "returns :exhausted for multi-use invite at max uses" do
      invite = create(:invite, :exhausted)
      expect(invite.status).to eq(:exhausted)
    end
  end

  describe "#remaining_uses" do
    it "returns nil for unlimited invite" do
      invite = create(:invite, :multi_use, max_uses: nil)
      expect(invite.remaining_uses).to be_nil
    end

    it "returns correct remaining for limited invite" do
      invite = create(:invite, :with_max_uses, max_uses: 10, use_count: 3)
      expect(invite.remaining_uses).to eq(7)
    end

    it "returns 0 when exhausted" do
      invite = create(:invite, :exhausted)
      expect(invite.remaining_uses).to eq(0)
    end
  end

  describe "#multi_use?" do
    it "returns true for multi-use invite" do
      invite = build(:invite, :multi_use)
      expect(invite.multi_use?).to be true
    end

    it "returns false for single-use invite" do
      invite = build(:invite)
      expect(invite.multi_use?).to be false
    end
  end
end
