# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    region { :uk }
    role { :user }

    trait :us_region do
      region { :us }
    end

    trait :eu_region do
      region { :eu }
    end

    trait :session_reviewer do
      role { :session_reviewer }
    end

    trait :admin do
      role { :admin }
    end

    trait :with_full_consent do
      after(:create) do |user|
        Consent.required_consent_types.each do |consent_type|
          create(:consent, user: user, consent_type: consent_type)
        end
      end
    end
  end
end
