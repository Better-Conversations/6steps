# frozen_string_literal: true

# SessionIteration records a single question-response cycle within a JourneySession.
# Sensitive content (user_response, reflected_words, question_asked) is encrypted
# and subject to 30-day retention before redaction.
class SessionIteration < ApplicationRecord
  has_paper_trail

  # Encrypted fields for sensitive content
  encrypts :user_response
  encrypts :question_asked
  encrypts :reflected_words

  # Associations
  belongs_to :journey_session

  # Validations
  validates :iteration_number, presence: true,
                               numericality: {
                                 greater_than: 0,
                                 less_than_or_equal_to: JourneySession::MAX_ITERATIONS
                               }
  validates :space_explored, inclusion: {
    in: JourneySession::SPACES + [ "integration" ]
  }, allow_nil: true

  # Scopes
  scope :for_cleanup, -> { where("created_at < ?", 30.days.ago) }
  scope :in_order, -> { order(:iteration_number) }
  scope :with_intervention, -> { where.not(safety_intervention: nil) }

  # Class methods

  # Redact old content while preserving metadata for safety analysis
  def self.cleanup_old_content!
    for_cleanup.find_each do |iteration|
      iteration.update!(
        user_response: "[REDACTED]",
        reflected_words: "[REDACTED]",
        question_asked: "[REDACTED]"
      )
    end
  end

  # Instance methods

  # Check if this iteration had a safety intervention
  def had_intervention?
    safety_intervention.present?
  end

  # Check if content has been redacted
  def redacted?
    user_response == "[REDACTED]"
  end

  # Get a safe summary for export (respects redaction)
  def export_data
    if redacted?
      {
        iteration: iteration_number,
        space: space_explored,
        redacted: true
      }
    else
      {
        iteration: iteration_number,
        space: space_explored,
        reflected_words: reflected_words,
        redacted: false
      }
    end
  end
end
