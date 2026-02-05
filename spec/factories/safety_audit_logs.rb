FactoryBot.define do
  factory :safety_audit_log do
    journey_session { nil }
    event_type { 1 }
    trigger_data { "" }
    depth_score_snapshot { 1.5 }
    response_taken { "MyString" }
  end
end
