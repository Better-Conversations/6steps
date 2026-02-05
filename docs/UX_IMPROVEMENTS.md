# UX Improvements for User Onboarding

This document captures planned UX improvements to help users adapt to the Clean Language / Emergent Knowledge approach used in Six Steps.

## The Challenge

The approach can feel unusual to newcomers:
- Reflective questions that mirror the user's own words
- The "six spaces" metaphor for exploring perspectives
- No direct advice or solutions offered
- Questions that may feel strange at first

Users need orientation before diving in, especially for their first session.

---

## Implemented Improvements

### 1. First-Session Onboarding Flow (Priority: HIGH)
**Status**: Implemented

For users who haven't completed a session yet, show an orientation before space selection:
- Brief explanation of what to expect
- Visual introduction to the six spaces
- Setting expectations about the unusual question style
- Reassurance that uncertainty is normal

### 2. Improved Space Selection (Priority: HIGH)
**Status**: Implemented

Enhanced the space selection interface:
- Each space has a contextual description/prompt
- Visual metaphor showing the six positions
- "Help me choose" guidance available
- Clear indication that there's no "wrong" choice

### 3. About the Approach Page (Priority: HIGH)
**Status**: Implemented

Static page accessible from footer explaining:
- The origins of the technique (David Grove's work)
- How it differs from therapy or advice
- What users can expect from the experience
- Why questions feel different

---

## Planned Improvements (Future)

### 4. Contextual Hints During Session (Priority: MEDIUM)
**Status**: Planned

Subtle, dismissible hints during first 1-2 sessions:
- At space selection: "Pick whichever feels most relevant right now"
- At first question: "Take your time. There's no wrong answer."
- For short responses: "Feel free to say more, or this is enough"

Implementation approach:
- Track `sessions_completed_count` on User model
- Show hints only when count < 2
- Make hints dismissible with "Don't show again" option
- Store dismissal preference in user settings

### 5. Example Session Walkthrough (Priority: MEDIUM)
**Status**: Planned

Optional viewing of an anonymized example session:
- Shows the question/response/reflection flow
- Demonstrates how words are mirrored back
- Illustrates progression through iterations
- Available from onboarding or help section

Implementation approach:
- Create static example data (not real user data)
- Build read-only session viewer component
- Link from onboarding and About page

### 6. "New Here?" Dashboard Section (Priority: LOW)
**Status**: Planned

For first-time users, dashboard shows orientation section:
- Links to About the Approach
- Quick tips for getting started
- Disappears after first completed session

Implementation approach:
- Conditional rendering based on session count
- Card component with helpful links
- "Dismiss" option to hide permanently

### 7. Progress Indicators (Priority: LOW)
**Status**: Implemented

Help users understand where they are in a session:
- Visual progress bar showing exploration progress
- Label shows "Exploring" (not numeric counts)
- Not gamified - just orientation

Implementation notes:
- Progress bar in session view
- Minimal and non-distracting
- No numeric iteration counts shown to users

---

## Design Principles

When implementing these improvements, follow these principles:

1. **Gentle, not prescriptive**: Guide without telling users what to think or feel
2. **Respect the approach**: Don't undermine the "clean" nature of the questions
3. **Dismissible**: Let users skip orientation if they prefer
4. **Non-intrusive**: Hints should support, not interrupt the reflective state
5. **Accessible**: All content should work with screen readers
6. **Mobile-friendly**: Onboarding works well on phones

---

## Content Guidelines

### Tone
- Warm but not overly friendly
- Clear but not clinical
- Reassuring but not patronizing
- Honest about the unusual nature of the approach

### Key Messages to Convey
1. This is exploration, not therapy
2. Your words matter - we reflect them back
3. There's no right or wrong answer
4. Feeling uncertain is normal and okay
5. The strangeness is intentional and purposeful

### Words to Avoid
- "Treatment", "healing", "therapy"
- "AI", "algorithm" (even though we use pattern matching)
- "Diagnose", "assess", "evaluate"
- Anything that sounds like medical advice

---

## Testing Checklist

Before releasing onboarding improvements:

- [ ] Test with someone unfamiliar with Clean Language
- [ ] Verify all content is accessible (screen reader test)
- [ ] Check mobile responsiveness
- [ ] Ensure hints can be dismissed
- [ ] Verify orientation only shows for new users
- [ ] Test that returning users go straight to session

---

## Colour Palette & Visual Consistency

### Six Spaces Colour Scheme
The six spaces use a cohesive blue → indigo → violet → purple → amber → yellow gradient:

| Space | Background | Icon Colour |
|-------|------------|-------------|
| Here | Blue-100 | Blue-600 |
| There | Indigo-100 | Indigo-600 |
| Before | Violet-100 | Violet-600 |
| After | Purple-100 | Purple-600 |
| Inside | Amber-100 | Amber-600 |
| Outside | Yellow-100 | Yellow-600 |

### Status Colours
- **Success/Positive**: Emerald (completed states, confirmations)
- **Warning/Caution**: Amber (pause suggestions, warnings)
- **Error/Crisis**: Rose (errors, crisis alerts, emergency notices)
- **Info/Neutral**: Violet (primary brand, links, session progress)

### Button Consistency
All primary action buttons use consistent styling:
- Size: `px-4 py-2 text-sm font-medium`
- Icons: `w-4 h-4` (when present)
- Style: `rounded-lg` with focus rings

### Grounding Exercises
Updated for accessibility and inclusivity:
- **Breathing Pause**: "Focus on the rise and fall of your breathing" (position-neutral)
- **Notice Your Surroundings**: Visual grounding with option to repeat for other senses (hearing, touch, smell, taste)
- **Body Anchor**: Hand temperature awareness
- **Simple Pause**: Permission to take time

---

## Related Files

- `app/views/pages/approach.html.erb` - About the Approach page
- `app/views/journey_sessions/onboarding.html.erb` - First-session orientation
- `app/views/journey_sessions/_space_selection.html.erb` - Space selection partial
- `app/controllers/pages_controller.rb` - Static pages controller
- `app/controllers/journey_sessions_controller.rb` - Session flow controller
- `app/helpers/journey_sessions_helper.rb` - Space colour and icon helpers
- `app/services/crisis_resources.rb` - Grounding exercises and crisis resources
- `app/services/question_generator.rb` - Space descriptions and questions
