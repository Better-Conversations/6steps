# frozen_string_literal: true

# QuestionGenerator creates clean language questions for the Six Spaces reflection approach.
# Questions are designed to:
# - Never introduce new concepts (only reflect user's words)
# - Stay in present tense
# - Be minimally assumptive
# - Not probe into trauma or relationships
class QuestionGenerator
  # Question templates for each iteration (steps 2-6, step 1 is space-specific)
  # %{space} = the chosen space (here, there, before, after, inside, outside)
  # %{x} = reflected words from user's previous response
  QUESTION_TEMPLATES = {
    2 => {
      primary: "And when %{x}, what do you notice?",
      follow_up: "And where is %{x}?"
    },
    3 => {
      primary: "And what kind of %{x} is that %{x}?",
      follow_up: "Is there anything else about %{x}?"
    },
    4 => {
      primary: "And is there anything else about %{x}?",
      follow_up: "And whereabouts is %{x}?"
    },
    5 => {
      primary: "And what does %{x} know?",
      follow_up: "What else is there?"
    },
    6 => {
      primary: "And when %{x}, what do you know now?",
      follow_up: nil
    }
  }.freeze

  # Space-specific first questions for step 1
  # These are "cleanish" - adapted for a lay audience without a facilitator
  # They help users understand what they're being asked while maintaining Clean Language structure
  SPACE_FIRST_QUESTIONS = {
    here: "And what do you notice in this present moment?",
    there: "And where would you like to be?",
    before: "And what was life like before?",
    after: "And what has happened since?",
    inside: "And what do you notice in yourself?",
    outside: "And what do you notice outside yourself?"
  }.freeze

  # Space descriptions for selection UI
  # Each space has:
  # - name: Display name
  # - description: Short description for the card
  # - prompt: A gentle guiding question to help users understand what to explore
  SPACE_DESCRIPTIONS = {
    here: {
      name: "Here",
      description: "The present moment."
    },
    there: {
      name: "There",
      description: "Where you'd like to be."
    },
    before: {
      name: "Before",
      description: "Life before the change."
    },
    after: {
      name: "After",
      description: "What has happened since."
    },
    inside: {
      name: "Inside",
      description: "Your internal world."
    },
    outside: {
      name: "Outside",
      description: "The world around you."
    }
  }.freeze

  # Integration/closing question (used when transitioning to integration phase)
  # This is now the only closing question - combines integration and closing
  INTEGRATION_QUESTION = "And what do you know now that you didn't know before?"

  # DEPRECATED: Closing question removed - integration question serves as the only closing
  # Kept for backwards compatibility but no longer used in the flow
  CLOSING_QUESTION = "And is there anything else you know now?"

  def initialize(session)
    @session = session
  end

  # Generate the next question based on current session state
  def generate_next(user_input = nil)
    iteration = @session.iteration_count + 1

    # If we've hit the limit, return integration question
    return integration_question if iteration > JourneySession::MAX_ITERATIONS

    # Extract reflected words from user input
    reflected_word = extract_key_concept(user_input) if user_input

    # For iteration 1, we shouldn't be calling generate_next
    # (first_question_for_space is used instead)
    # But handle it gracefully if called
    if iteration == 1
      question = first_question_for_space(@session.current_space)
    else
      template = QUESTION_TEMPLATES[iteration]
      return nil unless template
      question = build_question(template[:primary], reflected_word)
    end

    # Store in session for audit trail
    @session.update!(
      pending_question: question,
      reflected_words_cache: reflected_word
    )

    question
  end

  # Generate the first question for a selected space
  def first_question_for_space(space)
    space_sym = space.to_s.to_sym
    SPACE_FIRST_QUESTIONS[space_sym] || "And when #{humanize_space(space)}, what do you notice?"
  end

  # Generate a follow-up question if needed
  def follow_up_question(user_input)
    iteration = @session.iteration_count
    template = QUESTION_TEMPLATES[iteration]

    return nil unless template && template[:follow_up]

    reflected_word = extract_key_concept(user_input)
    build_question(template[:follow_up], reflected_word)
  end

  # Get the integration question
  def integration_question
    INTEGRATION_QUESTION
  end

  # DEPRECATED: Get the closing question
  # The integration question now serves as the only closing question.
  # This method is kept for backwards compatibility but should not be used.
  def closing_question
    CLOSING_QUESTION
  end

  # Get all space options with descriptions
  def self.space_options
    SPACE_DESCRIPTIONS.map do |key, description|
      { key: key, label: key.capitalize, description: description }
    end
  end

  private

  def build_question(template, reflected_word)
    space_name = humanize_space(@session.current_space)

    substitutions = {
      space: space_name,
      x: reflected_word || "that",
      metaphor: extract_metaphor(reflected_word)
    }

    template % substitutions
  rescue KeyError => e
    # If substitution fails, return a safe fallback
    Rails.logger.warn "QuestionGenerator substitution failed: #{e.message}"
    "And what else is there?"
  end

  def humanize_space(space)
    case space
    when "here" then "here"
    when "there" then "there"
    when "before" then "before"
    when "after" then "after"
    when "inside" then "inside"
    when "outside" then "outside"
    else "here"
    end
  end

  # Extract a key concept from user input to reflect back
  # This is intentionally simple to maintain "clean" principles
  def extract_key_concept(input)
    return nil if input.blank?

    # Clean the input: lowercase, remove punctuation, normalize whitespace
    cleaned = input.to_s
                   .strip
                   .downcase
                   .gsub(/[.,!?;:'"()\[\]{}]/, " ")  # Remove punctuation
                   .gsub(/\s+/, " ")                  # Normalize whitespace
                   .strip

    # Remove common filler words and verbs (we want noun phrases for Clean Language)
    filler_words = %w[
      a an the and or but if so when where what how why which
      i me my mine myself you your yours he she it they them its
      is are was were am be been being have has had do does did
      will would could should may might must can
      just very really quite actually kind of sort of
      um uh like well so yeah yes no
      there here this that these those
      im i'm it's that's what's
      notice feel think know see hear want need try
      feeling thinking knowing seeing hearing wanting needing trying
      felt thought knew saw heard wanted needed tried
      going come came get got take took give gave
      make made find found seem look looking seems looked
    ]

    words = cleaned.split(/\s+/).reject do |word|
      word.length < 3 || filler_words.include?(word)
    end

    # Return the last 1-2 significant words for clean, readable questions
    return nil if words.empty?

    # Prefer fewer words for cleaner questions
    significant_words = words.last([ words.length, 2 ].min)
    significant_words.join(" ")
  end

  # Look for metaphor patterns in user input
  def extract_metaphor(input)
    return nil if input.blank?

    # Simple pattern matching for "like a..." or "like..." phrases
    if match = input.to_s.match(/like\s+(?:a\s+)?(.+?)(?:\.|,|$)/i)
      match[1].strip
    else
      nil
    end
  end
end
