# frozen_string_literal: true

require "ostruct"

namespace :smoke_test do
  desc "Run integration smoke tests to catch wiring issues"
  task all: :environment do
    puts "\n" + "=" * 60
    puts "SIX STEPS - INTEGRATION SMOKE TEST"
    puts "=" * 60 + "\n"

    errors = []
    warnings = []

    # Test 1: Model loading and associations
    puts "\n[1/10] Testing model loading and associations..."
    begin
      User.new
      Consent.new
      JourneySession.new
      SessionIteration.new
      SafetyAuditLog.new
      puts "  ✓ All models load successfully"
    rescue => e
      errors << "Model loading failed: #{e.message}"
      puts "  ✗ #{e.message}"
    end

    # Test 2: User model methods
    puts "\n[2/10] Testing User model methods..."
    begin
      user = User.new(email: "test@example.com", region: :uk)
      user.can_review_sessions? rescue errors << "User#can_review_sessions? failed"
      user.can_start_session? rescue errors << "User#can_start_session? failed"
      user.active_consent_for?(:terms_of_service) rescue errors << "User#active_consent_for? failed"
      puts "  ✓ User model methods work"
    rescue => e
      errors << "User model methods failed: #{e.message}"
      puts "  ✗ #{e.message}"
    end

    # Test 3: Consent model
    puts "\n[3/10] Testing Consent model..."
    begin
      types = Consent.required_consent_types
      raise "required_consent_types returned empty" if types.empty?
      types.each do |type|
        raise "Invalid consent type: #{type}" unless Consent.consent_types.keys.include?(type.to_s)
      end
      puts "  ✓ Consent types are valid: #{types.join(', ')}"
    rescue => e
      errors << "Consent model failed: #{e.message}"
      puts "  ✗ #{e.message}"
    end

    # Test 4: JourneySession state machine
    puts "\n[4/10] Testing JourneySession state machine..."
    begin
      session = JourneySession.new
      raise "Initial state should be :welcome" unless session.welcome?
      raise "Missing may_give_consent?" unless session.respond_to?(:may_give_consent?)
      raise "Missing may_select_space?" unless session.respond_to?(:may_select_space?)
      raise "Missing may_continue_iteration?" unless session.respond_to?(:may_continue_iteration?)
      raise "Missing may_pause?" unless session.respond_to?(:may_pause?)
      raise "Missing may_complete?" unless session.respond_to?(:may_complete?)
      puts "  ✓ State machine configured correctly"
    rescue => e
      errors << "JourneySession state machine failed: #{e.message}"
      puts "  ✗ #{e.message}"
    end

    # Test 5: SafetyMonitor service
    puts "\n[5/10] Testing SafetyMonitor service..."
    begin
      # SafetyMonitor requires a session object
      mock_session = OpenStruct.new(
        current_depth_score: 0.0,
        iteration_count: 0,
        duration_minutes: 0,
        grounding_insertions_count: 0
      )

      monitor = SafetyMonitor.new(mock_session)
      monitor.assess("I feel sad today")
      raise "Missing depth_score" unless monitor.depth_score.is_a?(Numeric)
      raise "Missing safety_level" unless monitor.safety_level.is_a?(Symbol)

      # Test crisis detection
      crisis_monitor = SafetyMonitor.new(mock_session)
      crisis_monitor.assess("I want to kill myself")
      raise "Crisis should be detected" unless crisis_monitor.crisis?
      puts "  ✓ SafetyMonitor working correctly"
    rescue => e
      errors << "SafetyMonitor failed: #{e.message}"
      puts "  ✗ #{e.message}"
    end

    # Test 6: CrisisResources service
    puts "\n[6/10] Testing CrisisResources service..."
    begin
      [ :uk, :us, :eu, :au ].each do |region|
        resources = CrisisResources.for_region(region)
        raise "Missing primary for #{region}" unless resources[:primary]
        raise "Missing emergency for #{region}" unless resources[:emergency]
      end

      exercises = CrisisResources.all_grounding_exercises
      raise "No grounding exercises" if exercises.empty?
      puts "  ✓ CrisisResources working for all regions"
    rescue => e
      errors << "CrisisResources failed: #{e.message}"
      puts "  ✗ #{e.message}"
    end

    # Test 7: QuestionGenerator service
    puts "\n[7/10] Testing QuestionGenerator service..."
    begin
      # Test space descriptions (static constant)
      spaces = QuestionGenerator::SPACE_DESCRIPTIONS
      [ :here, :there, :before, :after, :inside, :outside ].each do |space|
        raise "Missing space #{space}" unless spaces[space]
        raise "Space #{space} missing :name" unless spaces[space][:name]
        raise "Space #{space} missing :description" unless spaces[space][:description]
      end

      # QuestionGenerator requires a session
      mock_session = OpenStruct.new(
        iteration_count: 0,
        current_space: "here",
        update!: ->(**args) { true }
      )

      generator = QuestionGenerator.new(mock_session)

      # Test first question for space
      question = generator.first_question_for_space(:here)
      raise "First question empty" if question.nil? || question.empty?

      # Test integration question
      integration_q = generator.integration_question
      raise "Integration question empty" if integration_q.nil? || integration_q.empty?

      puts "  ✓ QuestionGenerator working correctly"
    rescue => e
      errors << "QuestionGenerator failed: #{e.message}"
      puts "  ✗ #{e.message}"
    end

    # Test 8: ConversationEngine service
    puts "\n[8/10] Testing ConversationEngine service..."
    begin
      session = JourneySession.new(state: :welcome)
      engine = ConversationEngine.new(session)

      raise "Missing start_with_space method" unless engine.respond_to?(:start_with_space)
      raise "Missing process_response method" unless engine.respond_to?(:process_response)
      puts "  ✓ ConversationEngine interface correct"
    rescue => e
      errors << "ConversationEngine failed: #{e.message}"
      puts "  ✗ #{e.message}"
    end

    # Test 9: Controller helpers
    puts "\n[9/10] Testing controller constants and helpers..."
    begin
      # ConsentsController
      require_relative "../../app/controllers/consents_controller"
      consent_types = ConsentsController::CONSENT_INFO.keys
      consent_types.each do |type|
        unless Consent.consent_types.keys.include?(type.to_s)
          errors << "ConsentsController has invalid consent type: #{type}"
        end
      end

      # Check JourneySessionsHelper
      require_relative "../../app/helpers/journey_sessions_helper"
      helper = Class.new { include JourneySessionsHelper }.new
      helper.space_color_class(:here) rescue errors << "JourneySessionsHelper#space_color_class failed"
      helper.session_state_class(:completed) rescue errors << "JourneySessionsHelper#session_state_class failed"

      puts "  ✓ Controller constants and helpers valid"
    rescue => e
      errors << "Controller helpers failed: #{e.message}"
      puts "  ✗ #{e.message}"
    end

    # Test 10: SafetyAuditLog event types
    puts "\n[10/10] Testing SafetyAuditLog event types..."
    begin
      event_types = SafetyAuditLog.event_types.keys
      required_events = %w[crisis_pattern_detected crisis_protocol_activated depth_threshold_crossed]
      required_events.each do |event|
        unless event_types.include?(event)
          errors << "SafetyAuditLog missing event type: #{event}"
        end
      end
      puts "  ✓ SafetyAuditLog event types valid"
    rescue => e
      errors << "SafetyAuditLog failed: #{e.message}"
      puts "  ✗ #{e.message}"
    end

    # Summary
    puts "\n" + "=" * 60
    if errors.empty?
      puts "✓ ALL SMOKE TESTS PASSED"
      puts "=" * 60
    else
      puts "✗ #{errors.size} ERROR(S) FOUND:"
      puts "=" * 60
      errors.each { |e| puts "  - #{e}" }
      exit 1
    end
  end
end
