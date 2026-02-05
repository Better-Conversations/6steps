FactoryBot.define do
  factory :session_iteration do
    journey_session
    iteration_number { 1 }
    question_asked { "And what do you notice?" }
    user_response { "I notice a sense of calm" }
    reflected_words { "calm" }
    space_explored { "here" }
    depth_score_at_end { 0.2 }
    safety_intervention { nil }

    trait :with_intervention do
      safety_intervention { "grounding" }
    end

    trait :redacted do
      user_response { "[REDACTED]" }
      question_asked { "[REDACTED]" }
      reflected_words { "[REDACTED]" }
    end

    trait :old do
      created_at { 31.days.ago }
    end
  end
end
