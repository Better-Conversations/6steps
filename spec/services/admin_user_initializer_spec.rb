# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminUserInitializer do
  describe ".call" do
    context "when no users exist and environment variables are set" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ADMIN_EMAIL").and_return("admin@example.com")
        allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("securepass123")
        allow(ENV).to receive(:fetch).with("ADMIN_REGION", "uk").and_return("uk")
      end

      it "creates an admin user" do
        expect { described_class.call }.to change(User, :count).by(1)
      end

      it "returns true" do
        expect(described_class.call).to be true
      end

      it "sets the user as admin" do
        described_class.call
        expect(User.last.role_admin?).to be true
      end

      it "sets the correct email" do
        described_class.call
        expect(User.last.email).to eq("admin@example.com")
      end

      it "sets the default region to uk" do
        described_class.call
        expect(User.last.region_uk?).to be true
      end

      it "creates all 4 required consents" do
        described_class.call
        user = User.last

        expect(user.consents.count).to eq(4)
        Consent.required_consent_types.each do |consent_type|
          expect(user.active_consent_for?(consent_type)).to be true
        end
      end

      it "marks consents with system-init ip_address" do
        described_class.call
        expect(User.last.consents.pluck(:ip_address)).to all(eq("system-init"))
      end

      it "allows the user to start sessions" do
        described_class.call
        expect(User.last.can_start_session?).to be true
      end
    end

    context "when users already exist" do
      before do
        create(:user)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ADMIN_EMAIL").and_return("admin@example.com")
        allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("securepass123")
      end

      it "does not create a new user" do
        expect { described_class.call }.not_to change(User, :count)
      end

      it "returns false" do
        expect(described_class.call).to be false
      end
    end

    context "when ADMIN_EMAIL is missing" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ADMIN_EMAIL").and_return(nil)
        allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("securepass123")
      end

      it "does not create a user" do
        expect { described_class.call }.not_to change(User, :count)
      end

      it "returns false" do
        expect(described_class.call).to be false
      end
    end

    context "when ADMIN_PASSWORD is missing" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ADMIN_EMAIL").and_return("admin@example.com")
        allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return(nil)
      end

      it "does not create a user" do
        expect { described_class.call }.not_to change(User, :count)
      end

      it "returns false" do
        expect(described_class.call).to be false
      end
    end

    context "when password is too short" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ADMIN_EMAIL").and_return("admin@example.com")
        allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("short")
      end

      it "does not create a user" do
        expect { described_class.call }.not_to change(User, :count)
      end

      it "returns false" do
        expect(described_class.call).to be false
      end
    end

    context "when password is too long" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ADMIN_EMAIL").and_return("admin@example.com")
        allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("a" * 129)
      end

      it "does not create a user" do
        expect { described_class.call }.not_to change(User, :count)
      end

      it "returns false" do
        expect(described_class.call).to be false
      end
    end

    context "when region is invalid" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ADMIN_EMAIL").and_return("admin@example.com")
        allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("securepass123")
        allow(ENV).to receive(:fetch).with("ADMIN_REGION", "uk").and_return("invalid_region")
      end

      it "does not create a user" do
        expect { described_class.call }.not_to change(User, :count)
      end

      it "returns false" do
        expect(described_class.call).to be false
      end
    end

    context "with custom region setting" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ADMIN_EMAIL").and_return("admin@example.com")
        allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("securepass123")
        allow(ENV).to receive(:fetch).with("ADMIN_REGION", "uk").and_return("us")
      end

      it "creates user with specified region" do
        described_class.call
        expect(User.last.region_us?).to be true
      end
    end

    context "when email is invalid" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ADMIN_EMAIL").and_return("not-an-email")
        allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("securepass123")
        allow(ENV).to receive(:fetch).with("ADMIN_REGION", "uk").and_return("uk")
      end

      it "does not create a user" do
        expect { described_class.call }.not_to change(User, :count)
      end

      it "returns false" do
        expect(described_class.call).to be false
      end
    end
  end

  describe "idempotency" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ADMIN_EMAIL").and_return("admin@example.com")
      allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("securepass123")
      allow(ENV).to receive(:fetch).with("ADMIN_REGION", "uk").and_return("uk")
    end

    it "only creates one user when called multiple times" do
      expect { described_class.call }.to change(User, :count).by(1)
      expect { described_class.call }.not_to change(User, :count)
      expect { described_class.call }.not_to change(User, :count)
    end
  end
end
