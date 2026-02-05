# frozen_string_literal: true

FactoryBot.define do
  factory :consent do
    user
    consent_type { :sensitive_data_processing }
    version { "1.0" }
    given_at { Time.current }
    ip_address { "127.0.0.1" }
    withdrawn_at { nil }
    withdrawal_reason { nil }

    trait :terms_of_service do
      consent_type { :terms_of_service }
    end

    trait :privacy_policy do
      consent_type { :privacy_policy }
    end

    trait :session_reflections do
      consent_type { :session_reflections }
    end

    trait :withdrawn do
      withdrawn_at { Time.current }
      withdrawal_reason { "User requested withdrawal" }
    end

    trait :needs_renewal do
      given_at { 13.months.ago }
    end
  end
end
