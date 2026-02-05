# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionPdfExporter do
  let(:user) { create(:user) }
  let(:session) { create(:journey_session, user: user, state: :completed) }

  describe "#generate" do
    it "generates a PDF document" do
      exporter = described_class.new(session)
      pdf = exporter.generate

      expect(pdf).to be_a(Prawn::Document)
    end

    context "with session iterations containing special characters" do
      let(:mock_iteration) do
        instance_double(
          SessionIteration,
          iteration_number: 1,
          question_asked: "What would you like to explore?",
          user_response: "I feel happy today 😇 and grateful 🙏",
          reflected_words: "happy, grateful 💡"
        )
      end

      before do
        allow(session).to receive_message_chain(:session_iterations, :order)
          .and_return([ mock_iteration ])
      end

      it "handles emoji by replacing with placeholder" do
        exporter = described_class.new(session)

        expect { exporter.generate }.not_to raise_error
      end

      it "renders the PDF successfully" do
        exporter = described_class.new(session)
        pdf = exporter.generate

        expect(pdf.render).to be_present
      end
    end

    context "with various Unicode characters" do
      let(:mock_iteration) do
        instance_double(
          SessionIteration,
          iteration_number: 1,
          question_asked: "What would you like to explore?",
          user_response: "Testing: 日本語 émojis 😀🎉 symbols ★♠♥",
          reflected_words: nil
        )
      end

      before do
        allow(session).to receive_message_chain(:session_iterations, :order)
          .and_return([ mock_iteration ])
      end

      it "handles mixed Unicode content without raising errors" do
        exporter = described_class.new(session)

        expect { exporter.generate }.not_to raise_error
      end
    end

    context "with session summary containing emoji" do
      before do
        allow(session).to receive(:session_summary)
          .and_return("I learned something important today! 💡")
        allow(session).to receive_message_chain(:session_iterations, :order)
          .and_return([])
      end

      it "handles emoji in session summary" do
        exporter = described_class.new(session)

        expect { exporter.generate }.not_to raise_error
      end
    end

    context "with nil user response" do
      let(:mock_iteration) do
        instance_double(
          SessionIteration,
          iteration_number: 1,
          question_asked: "What would you like to explore?",
          user_response: nil,
          reflected_words: nil
        )
      end

      before do
        allow(session).to receive_message_chain(:session_iterations, :order)
          .and_return([ mock_iteration ])
      end

      it "handles nil response gracefully" do
        exporter = described_class.new(session)

        expect { exporter.generate }.not_to raise_error
      end
    end
  end

  describe "#sanitize_text" do
    let(:exporter) { described_class.new(session) }

    it "returns nil for nil input" do
      expect(exporter.send(:sanitize_text, nil)).to be_nil
    end

    it "preserves standard ASCII text" do
      text = "Hello, World!"
      expect(exporter.send(:sanitize_text, text)).to eq("Hello, World!")
    end

    it "preserves Windows-1252 compatible characters" do
      text = "Café résumé naïve"
      expect(exporter.send(:sanitize_text, text)).to eq("Café résumé naïve")
    end

    it "replaces emoji with short codes" do
      text = "Happy 😇 day"
      result = exporter.send(:sanitize_text, text)

      expect(result).to include("Happy")
      expect(result).to include("day")
      expect(result).to include(":innocent:")
      expect(result).not_to include("😇")
    end

    it "replaces multiple emoji with their short codes" do
      text = "🎉 Party 🎊 time"
      result = exporter.send(:sanitize_text, text)

      expect(result).to include("Party")
      expect(result).to include("time")
      expect(result).to include(":tada:")
      expect(result).to include(":confetti_ball:")
    end

    it "handles unsupported characters with placeholder" do
      text = "Hello 日 World"
      result = exporter.send(:sanitize_text, text)

      expect(result).to include("Hello")
      expect(result).to include("World")
      expect(result).to include("[?]")
    end

    it "handles multi-codepoint emoji sequences (ZWJ family)" do
      text = "Family: 👨‍👩‍👧‍👦"
      result = exporter.send(:sanitize_text, text)

      expect(result).to include("Family:")
      expect(result).to include(":family_man_woman_girl_boy:")
      expect(result).not_to include("👨")
    end

    it "handles emoji with skin tone modifiers" do
      text = "Thumbs up: 👍🏽 and wave: 👋🏿"
      result = exporter.send(:sanitize_text, text)

      expect(result).to include(":+1_tone3:")
      expect(result).to include(":wave_tone5:")
      expect(result).not_to include("👍")
      expect(result).not_to include("[?]")
    end
  end
end
