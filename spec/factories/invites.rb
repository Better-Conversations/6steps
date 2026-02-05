# frozen_string_literal: true

FactoryBot.define do
  factory :invite do
    association :created_by, factory: :user
    expires_at { 7.days.from_now }

    trait :with_email do
      email { Faker::Internet.email }
    end

    trait :multi_use do
      multi_use { true }
      email { nil }
    end

    trait :with_max_uses do
      multi_use { true }
      max_uses { 10 }
      email { nil }
    end

    trait :used do
      used_at { Time.current }
      association :used_by, factory: :user
      use_count { 1 }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :exhausted do
      multi_use { true }
      max_uses { 5 }
      use_count { 5 }
      used_at { Time.current }
      association :used_by, factory: :user
    end
  end
end
