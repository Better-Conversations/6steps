# frozen_string_literal: true

# ============================================================================
# COMPLIANCE WARNING - USER SAFETY
# ============================================================================
# This file contains crisis helpline data shown during safety interventions.
# Incorrect data could endanger users. Modifications require:
# 1. Verification of all phone numbers and URLs
# 2. Safety reviewer sign-off
# 3. Testing in all supported regions (UK, US, EU, AU)
#
# See COMPLIANCE.md Section 4 for review requirements.
# ============================================================================

# CrisisResources provides region-aware crisis helpline and support resource data.
# This data is used when the SafetyMonitor detects concerning patterns.
class CrisisResources
  RESOURCES = {
    uk: {
      primary: {
        name: "Samaritans",
        phone: "116 123",
        description: "24/7 emotional support for anyone in distress",
        url: "https://www.samaritans.org"
      },
      secondary: {
        name: "NHS 111",
        phone: "111",
        description: "NHS non-emergency medical advice",
        url: "https://111.nhs.uk"
      },
      mental_health: {
        name: "Mind",
        phone: "0300 123 3393",
        description: "Mental health charity helpline",
        url: "https://www.mind.org.uk"
      },
      emergency: {
        name: "Emergency Services",
        phone: "999",
        description: "For immediate danger to life"
      }
    },
    us: {
      primary: {
        name: "988 Suicide & Crisis Lifeline",
        phone: "988",
        description: "24/7 crisis support - call or text",
        url: "https://988lifeline.org"
      },
      secondary: {
        name: "Crisis Text Line",
        phone: "Text HOME to 741741",
        description: "24/7 text-based crisis support",
        url: "https://www.crisistextline.org"
      },
      mental_health: {
        name: "NAMI Helpline",
        phone: "1-800-950-6264",
        description: "National Alliance on Mental Illness",
        url: "https://www.nami.org"
      },
      emergency: {
        name: "Emergency Services",
        phone: "911",
        description: "For immediate danger to life"
      }
    },
    eu: {
      primary: {
        name: "European Emergency Number",
        phone: "112",
        description: "Pan-European emergency number",
        url: nil
      },
      secondary: {
        name: "Befrienders Worldwide",
        phone: nil,
        description: "Find local support in your country",
        url: "https://www.befrienders.org/find-a-helpline"
      },
      mental_health: {
        name: "Mental Health Europe",
        phone: nil,
        description: "Resources across European countries",
        url: "https://www.mhe-sme.org"
      },
      emergency: {
        name: "Emergency Services",
        phone: "112",
        description: "For immediate danger to life"
      }
    },
    au: {
      primary: {
        name: "Lifeline Australia",
        phone: "13 11 14",
        description: "24/7 crisis support and suicide prevention",
        url: "https://www.lifeline.org.au"
      },
      secondary: {
        name: "Beyond Blue",
        phone: "1300 22 4636",
        description: "Anxiety, depression and suicide prevention",
        url: "https://www.beyondblue.org.au"
      },
      mental_health: {
        name: "SANE Australia",
        phone: "1800 187 263",
        description: "Mental health support",
        url: "https://www.sane.org"
      },
      emergency: {
        name: "Emergency Services",
        phone: "000",
        description: "For immediate danger to life"
      }
    },
    other: {
      primary: {
        name: "International Association for Suicide Prevention",
        phone: nil,
        description: "Find crisis centers worldwide",
        url: "https://www.iasp.info/resources/Crisis_Centres/"
      },
      secondary: {
        name: "Befrienders Worldwide",
        phone: nil,
        description: "Find local emotional support",
        url: "https://www.befrienders.org/find-a-helpline"
      },
      emergency: {
        name: "Local Emergency Services",
        phone: nil,
        description: "Contact your local emergency number"
      }
    }
  }.freeze

  # Grounding exercises to offer during amber/orange interventions
  GROUNDING_EXERCISES = [
    {
      name: "Breathing Pause",
      instructions: [
        "Let's take a breath together.",
        "Focus on the rise and fall of your breathing.",
        "What do you notice in this moment?"
      ]
    },
    {
      name: "Notice Your Surroundings",
      instructions: [
        "Look around you.",
        "What's one thing you can see right now?",
        "You can repeat this with other senses: hearing, touch, smell, taste."
      ]
    },
    {
      name: "Body Anchor",
      instructions: [
        "That's a lot to hold.",
        "Feel your hands - are they warm or cool?",
        "When you're ready, we can continue gently."
      ]
    },
    {
      name: "Simple Pause",
      instructions: [
        "Let's pause here for a moment.",
        "There's no rush.",
        "Take whatever time you need."
      ]
    }
  ].freeze

  class << self
    # Get all resources for a specific region
    def for_region(region)
      region_key = region.to_s.downcase.to_sym
      RESOURCES[region_key] || RESOURCES[:other]
    end

    # Get the primary crisis resource for a region
    def primary_for_region(region)
      for_region(region)[:primary]
    end

    # Get emergency contact for a region
    def emergency_for_region(region)
      for_region(region)[:emergency]
    end

    # Get a random grounding exercise
    def random_grounding_exercise
      GROUNDING_EXERCISES.sample
    end

    # Get all grounding exercises
    def all_grounding_exercises
      GROUNDING_EXERCISES
    end

    # Format resources for display
    def formatted_for_display(region)
      resources = for_region(region)

      resources.map do |key, resource|
        next if key == :emergency # Handle emergency separately

        {
          key: key,
          name: resource[:name],
          contact: resource[:phone] || resource[:url],
          description: resource[:description],
          url: resource[:url],
          is_phone: resource[:phone].present?
        }
      end.compact
    end

    # Generate crisis modal content
    def crisis_modal_content(region)
      resources = for_region(region)

      {
        header: "Support Options",
        message: "Here are some resources you might find useful.",
        resources: formatted_for_display(region),
        emergency: resources[:emergency],
        footer: "If you are in immediate danger, please contact emergency services."
      }
    end
  end
end
