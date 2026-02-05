# Six Steps - Claude Code Guidelines

## CRITICAL: Regulatory Compliance

**READ FIRST:** See `COMPLIANCE.md` for full regulatory documentation.

This application is subject to UK/EU GDPR and designed to avoid EU AI Act classification. The following changes **REQUIRE compliance review before implementation**:

| Change Type | Risk Level | Action Required |
|-------------|------------|-----------------|
| Adding AI/ML components | **CRITICAL** | Full EU AI Act assessment required |
| Modifying `SafetyMonitor` patterns | **HIGH** | Safety review + exhaustive testing |
| Changing depth thresholds | **HIGH** | Safety review + documentation |
| Adding new data collection | **HIGH** | DPO review for GDPR impact |
| Modifying consent types | **HIGH** | Legal review |
| Changing data retention | **MEDIUM** | DPO review |
| Adding health/therapeutic claims | **CRITICAL** | Medical device regulation risk |

**DO NOT** implement any of the above without explicit authorization.

## Project Overview

Six Steps is a Rails 8.0+ application offering quiet spaces for self-reflection, using the Six Spaces technique inspired by David Grove's Emergent Knowledge. This is a tool for structured self-reflection - it is not intended as a substitute for professional coaching, counselling, or therapy. Safety guardrails are included to ensure a supportive experience for all users.

## Stack

- **Backend**: Rails 8.0+ with PostgreSQL
- **Frontend**: Stimulus JS + Turbo + Tailwind CSS
- **Background Jobs**: Solid Queue (database-backed, no Redis)
- **Caching**: Solid Cache (database-backed)
- **WebSockets**: Solid Cable (database-backed)
- **Testing**: RSpec with FactoryBot
- **Auth**: Devise
- **State Machine**: AASM
- **Audit Trail**: PaperTrail
- **Encryption**: Rails Active Record Encryption

## Code Style

- **Models**: "Fat models, skinny controllers" - business logic in models/services
- **Naming**: snake_case for files/methods, CamelCase for classes
- **Indentation**: 2 spaces
- **Line Length**: ~100 characters

## Key Architecture

### Safety-First Design

The SafetyMonitor service (`app/services/safety_monitor.rb`) uses DETERMINISTIC pattern matching, not AI:
- All crisis detection is via regex patterns
- Depth scores are calculated from word counts
- This ensures testable, auditable, predictable behaviour

### Core Models

- `User` - Devise auth, region (for crisis resources), role (user, session_reviewer, admin)
- `Consent` - GDPR-compliant consent tracking (required types: terms_of_service, privacy_policy, sensitive_data_processing, session_reflections)
- `JourneySession` - AASM state machine for session flow (uses `state` column)
- `SessionIteration` - Individual question-response cycles (encrypted fields)
- `SafetyAuditLog` - Compliance audit trail (event types: crisis_pattern_detected, crisis_protocol_activated, depth_threshold_crossed, etc.)
- `Invite` - Secure invite tokens for registration (public registration disabled)

### Services

- `SafetyMonitor` - Crisis detection and depth scoring (requires session in constructor)
- `ConversationEngine` - Orchestrates session flow
- `QuestionGenerator` - Clean language question generation
- `CrisisResources` - Region-aware helpline data (UK, US, EU, AU)

## Development Environment

**IMPORTANT:** Always use the devcontainer for running Rails commands. The host machine may have a different Ruby version.

Start the devcontainer from VS Code or Cursor first (use "Reopen in Container"). Once running, execute commands via docker.

**Note:** The container name may vary (e.g., `devcontainer-app-1` vs `six-steps_devcontainer-app-1`). Use `docker ps --filter "name=devcontainer"` to find the correct name.

```bash
# Run commands inside the devcontainer
docker exec <container> <command>

# Examples:
docker exec <container> bin/rails db:migrate
docker exec <container> bin/rails console

# IMPORTANT: Always set RAILS_ENV=test when running tests
# The devcontainer defaults to RAILS_ENV=development
docker exec -e RAILS_ENV=test <container> bundle exec rspec
```

## Testing

### Run smoke tests first (quick integration check):
```bash
docker exec -e RAILS_ENV=test <container> bin/rails smoke_test:all
```

### Run safety tests (critical):
```bash
docker exec -e RAILS_ENV=test <container> bundle exec rspec spec/services/safety_monitor_spec.rb
```

### Run all tests:
```bash
docker exec -e RAILS_ENV=test <container> bundle exec rspec
```

## Commands

```bash
docker exec <container> bin/rails db:migrate           # Run migrations
docker exec <container> bin/rails server               # Start dev server
docker exec -e RAILS_ENV=test <container> bundle exec rspec   # Run tests
docker exec <container> bin/rails console              # Rails console
docker exec -e RAILS_ENV=test <container> bin/rails smoke_test:all # Integration smoke tests
docker exec <container> bin/rails db:encryption:init   # Generate encryption keys (if needed)
```

## Important Notes

1. **Safety First**: Never modify SafetyMonitor without running exhaustive tests
2. **Encryption**: Sensitive fields use Rails encrypted attributes - keys must be in credentials
3. **Audit Trail**: All safety events must be logged via SafetyAuditLog
4. **Not Professional Support**: Clear disclaimers throughout the UI - DO NOT add coaching, counselling, or therapeutic claims
5. **Data Retention**: 30-day content redaction policy via `DataRetentionJob`
6. **State Column**: JourneySession uses `state` column, not `aasm_state`
7. **Invite-Only Registration**: Public registration disabled - users need valid invite link
8. **No AI**: System uses deterministic pattern matching - adding AI requires EU AI Act compliance
9. **Compliance Doc**: See `COMPLIANCE.md` for change review requirements

## Authentication & User Roles

### Invite System

Public registration is disabled. Users can only register with a valid invite link:
- Invites created by admins at `/admin/invites`
- Invite URL format: `/users/sign_up?invite=TOKEN`
- **Single-use invites**: Default, one person per invite, optional email restriction
- **General links (multi-use)**: For community sharing, optional max_uses limit, no email restriction
- Configurable expiry (1-30 days, default 7)

### User Roles

- `user` (default): Standard access to sessions
- `session_reviewer`: Access to admin dashboard for anonymized session review
- `admin`: Full admin access including invite management

### Making a User Admin

```bash
bin/rails runner 'User.find_by(email: "user@example.com").update!(role: :admin)'
```

## Common Integration Gotchas

- `SafetyMonitor.new` requires a session object
- `QuestionGenerator::SPACE_DESCRIPTIONS` uses `{key: {name:, description:}}` format
- `CrisisResources.all_grounding_exercises` (not `grounding_exercises`)
- Consent types must match `Consent.consent_types` enum values
- SafetyAuditLog event types: `crisis_pattern_detected`, `crisis_protocol_activated`, `depth_threshold_crossed`

## Compliance-Sensitive Files

The following files have regulatory implications - modifications require compliance review:

| File | Compliance Area |
|------|-----------------|
| `app/services/safety_monitor.rb` | Crisis detection - user safety |
| `app/jobs/data_retention_job.rb` | GDPR data minimization |
| `app/models/consent.rb` | GDPR lawful basis |
| `app/controllers/users/registrations_controller.rb` | GDPR data portability/erasure |
| `config/locales/*.yml` | "Not professional support" disclaimers |

## Why No AI

The system deliberately uses **deterministic rule-based processing** to:
1. Avoid EU AI Act High-Risk classification (Annex III, Section 5)
2. Ensure fully auditable, predictable behaviour
3. Enable exhaustive safety testing
4. Maintain session oversight capability

If AI features are ever considered, see `COMPLIANCE.md` Section 4 for mandatory steps.

## Adding New Features

### Git Workflow

1. **Create a branch first** using the git branch name from the Linear issue (available via `get_issue`)
2. Branch naming: `username/BCTT-XXX-short-description`
3. Commit frequently with meaningful messages
4. Don't commit to main directly

### Implementation Steps

When adding features that modify models, follow this pattern:

1. **Migration**: Generate with `docker exec devcontainer-app-1 bin/rails generate migration ...`
2. **Model**: Update model with scopes, validations, and instance methods
3. **Controller**: Update permitted params if adding new fields
4. **Views**: Update admin views (index, show, new/edit forms)
5. **Stimulus**: Add controllers to `app/javascript/controllers/` for interactive UI (auto-registered)
6. **Factory**: Create/update in `spec/factories/` with traits for different states
7. **Tests**: Add model specs in `spec/models/`

### Stimulus Controllers

Stimulus controllers are auto-loaded from `app/javascript/controllers/`. Name files as `foo_controller.js` and reference as `data-controller="foo"`. Use targets with `data-foo-target="bar"` and actions with `data-action="event->foo#method"`.

### Factories

Use traits to represent different object states:
```ruby
trait :multi_use do
  multi_use { true }
end

trait :expired do
  expires_at { 1.day.ago }
end
```

## Documentation

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Quick start and overview |
| [COMPLIANCE.md](COMPLIANCE.md) | Regulatory requirements (GDPR, EU AI Act) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design and data flow |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Hosting and deployment |
| [docs/ADMINISTRATION.md](docs/ADMINISTRATION.md) | User roles and management |
| [docs/TESTING.md](docs/TESTING.md) | Test commands and categories |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and solutions |
