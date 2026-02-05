# frozen_string_literal: true

require "emoji"

class SessionPdfExporter
  def initialize(journey_session)
    @session = journey_session
    @iterations = journey_session.session_iterations.order(:iteration_number)
  end

  def generate
    # Suppress Prawn's i18n warning since we handle encoding via sanitize_text
    Prawn::Fonts::AFM.hide_m17n_warning = true

    Prawn::Document.new do |pdf|
      setup_fonts(pdf)
      add_header(pdf)
      add_session_info(pdf)
      add_iterations(pdf)
      add_integration_insight(pdf)
      add_footer(pdf)
    end
  end

  private

  def setup_fonts(pdf)
    pdf.font_size 11
    pdf.default_leading 5
  end

  # Skin tone modifiers (Fitzpatrick scale U+1F3FB to U+1F3FF)
  SKIN_TONES = %W[\u{1F3FB} \u{1F3FC} \u{1F3FD} \u{1F3FE} \u{1F3FF}].freeze
  SKIN_TONE_REGEX = /[#{SKIN_TONES.join}]/

  # Sanitize text to remove characters not supported by Prawn's built-in fonts
  # (Windows-1252 encoding). Replaces emojis with short codes (e.g. :tada:) and
  # other unsupported characters with a placeholder to prevent PDF generation failures.
  def sanitize_text(text)
    return text if text.nil?

    # First, replace known emoji sequences with short codes
    # Regex is built on first use and memoized to avoid boot-time overhead
    result = text.gsub(emoji_regex) do |match|
      # Check for skin tone modifier in the match
      skin_tone = match.match(SKIN_TONE_REGEX)
      base_emoji = match.gsub(SKIN_TONE_REGEX, "")

      emoji = Emoji.find_by_unicode(base_emoji)
      if emoji
        tone_suffix = skin_tone ? "_tone#{SKIN_TONES.index(skin_tone[0]) + 1}" : ""
        ":#{emoji.aliases.first}#{tone_suffix}:"
      else
        match
      end
    end

    # Then handle any remaining non-Windows-1252 characters
    result.each_char.map do |char|
      begin
        char.encode("windows-1252")
        char
      rescue Encoding::UndefinedConversionError
        "[?]"
      end
    end.join
  end

  # Build emoji regex on first use (class-level memoization to reuse across instances)
  # Matches exact emoji sequences from gemoji, plus base emoji with skin tone suffix
  def self.emoji_regex
    @emoji_regex ||= begin
      all_emoji = Emoji.all.map(&:raw).compact.sort_by { |e| -e.length }
      # Add skin-toned variants for single-character emoji (not ZWJ sequences)
      patterns = all_emoji.flat_map do |e|
        if e.length == 1 || (e.codepoints.length == 1)
          # Single emoji - add pattern with optional skin tone
          [Regexp.escape(e) + SKIN_TONE_REGEX.source + "?"]
        else
          # Multi-codepoint sequence - match exactly as-is
          [Regexp.escape(e)]
        end
      end
      Regexp.new("(?:" + patterns.join("|") + ")")
    end
  end

  def emoji_regex
    self.class.emoji_regex
  end

  def add_header(pdf)
    pdf.text "Six Steps", size: 24, style: :bold
    pdf.text "Reflection Session Summary", size: 14, color: "666666"
    pdf.move_down 20

    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def add_session_info(pdf)
    pdf.text "Session Details", size: 16, style: :bold
    pdf.move_down 10

    info = [
      [ "Space Explored:", @session.current_space&.titleize || "Not specified" ],
      [ "Date:", @session.created_at.strftime("%B %d, %Y") ],
      [ "Time:", @session.created_at.strftime("%H:%M") ],
      [ "Iterations:", "#{@session.iteration_count} of 6" ],
      [ "Status:", @session.state.titleize ]
    ]

    info.each do |label, value|
      pdf.text "#{label} #{value}", inline_format: true
    end

    pdf.move_down 20
  end

  def add_iterations(pdf)
    return if @iterations.empty?

    pdf.text "Your Reflection Journey", size: 16, style: :bold
    pdf.move_down 10

    @iterations.each do |iteration|
      pdf.text "Step #{iteration.iteration_number}", style: :bold, color: "4F46E5"
      pdf.move_down 5

      pdf.text "Question:", style: :italic
      pdf.text "\"#{sanitize_text(iteration.question_asked)}\"", color: "666666"
      pdf.move_down 5

      pdf.text "Your Response:"
      pdf.text sanitize_text(iteration.user_response) || "(No response recorded)"
      pdf.move_down 5

      if iteration.reflected_words.present?
        pdf.text "Key words: #{sanitize_text(iteration.reflected_words)}", size: 10, color: "4F46E5"
      end

      pdf.move_down 15
    end
  end

  def add_integration_insight(pdf)
    return unless @session.session_summary.present?

    pdf.move_down 10
    pdf.stroke_horizontal_rule
    pdf.move_down 15

    pdf.text "Integration Insight", size: 16, style: :bold, color: "7C3AED"
    pdf.move_down 10

    pdf.text "\"What do you know now that you didn't know before?\"", style: :italic, color: "666666"
    pdf.move_down 5

    pdf.text sanitize_text(@session.session_summary)
  end

  def add_footer(pdf)
    pdf.move_down 30
    pdf.stroke_horizontal_rule
    pdf.move_down 10

    pdf.text "Important Notice", size: 10, style: :bold, color: "666666"
    pdf.move_down 5

    disclaimer = "This is a record of a self-reflection session from Six Steps. " \
                 "Six Steps is a tool for structured self-reflection. " \
                 "It is not intended as a substitute for professional coaching, counselling, or therapy. " \
                 "If you need support, please seek appropriate professional help."

    pdf.text disclaimer, size: 9, color: "888888"

    pdf.move_down 10
    pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}", size: 9, color: "888888"
  end
end
