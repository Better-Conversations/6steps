# frozen_string_literal: true

FactoryBot.define do
  factory :journey_session do
    user
    state { :welcome }
    current_space { nil }
    iteration_count { 0 }
    current_depth_score { 0.0 }
    started_at { nil }
    soft_time_limit_warned { false }
    session_summary { nil }
    pending_question { nil }
    reflected_words_cache { nil }
    grounding_insertions_count { 0 }

    trait :in_emergence_cycle do
      state { :emergence_cycle }
      current_space { "here" }
      started_at { Time.current }
    end

    trait :in_integration do
      state { :integration }
      current_space { "here" }
      started_at { 10.minutes.ago }
      iteration_count { 4 }
    end

    trait :completed do
      state { :completed }
      current_space { "here" }
      started_at { 20.minutes.ago }
      iteration_count { 6 }
      session_summary { "Session completed successfully." }
    end

    trait :paused do
      state { :paused }
      started_at { 5.minutes.ago }
    end

    trait :at_iteration_limit do
      iteration_count { 6 }
    end

    trait :near_time_limit do
      started_at { 28.minutes.ago }
    end

    trait :elevated_depth do
      current_depth_score { 0.5 }
    end
  end
end
