# Six Steps

A Rails application offering quiet spaces for self-reflection, using the Six Spaces technique inspired by David Grove's Emergent Knowledge.

**Six Steps is a tool for structured self-reflection.** It is not intended as a substitute for professional coaching, counselling, or therapy. Safety guardrails are included due to the origins of Clean Language techniques in therapeutic settings.

## Quick Start

```bash
# Clone and setup
git clone https://github.com/amphora/six-steps.git
cd six-steps
bundle install

# Database setup
bin/rails db:create db:migrate

# Run tests to verify setup
bundle exec rspec

# Start development server
bin/rails server
```

## First-Time Setup

### 1. Setup Encryption Keys

```bash
bin/rails db:encryption:init
EDITOR=vim bin/rails credentials:edit
```

Add the generated keys under `active_record_encryption`:

```yaml
active_record_encryption:
  primary_key: <generated_key>
  deterministic_key: <generated_key>
  key_derivation_salt: <generated_salt>
```

### 2. Create First Admin User

Since registration is invite-only, create the first user via console:

```bash
bin/rails console
```

```ruby
user = User.new(
  email: "admin@example.com",
  password: "your_secure_password",
  password_confirmation: "your_secure_password",
  region: :uk,  # or :us, :eu, :au
  role: :admin
)
user.save(validate: false)  # Skip invite validation for bootstrap
```

### 3. Verify Setup

```bash
bin/rails smoke_test:all
# You should see: "All smoke tests passed!"
```

## Requirements

- Ruby 3.2+
- Rails 8.0+
- PostgreSQL 15+
- Node.js 18+ (for Tailwind CSS compilation)

## Features

- **Six Spaces Technique**: Step into quiet spaces for reflection (Here, There, Before, After, Inside, Outside)
- **Bounded Sessions**: One space per session, 30-minute time limit
- **Safety System**: Deterministic crisis detection with grounding interventions
- **Region-Aware Resources**: Crisis helplines for UK, US, EU, AU
- **GDPR Compliant**: Consent management, 30-day data retention, right to erasure
- **Session Oversight**: Admin dashboard for anonymized session review
- **Invite-Only Access**: Secure invite system for controlled user registration
- **Audit Trail**: Full PaperTrail versioning on sensitive models

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | System design, services, and data flow |
| [Administration](docs/ADMINISTRATION.md) | User roles, invites, and management |
| [Testing](docs/TESTING.md) | Test commands and categories |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [Deployment](docs/DEPLOYMENT.md) | Hosting and infrastructure |
| [Compliance](COMPLIANCE.md) | GDPR, EU AI Act, regulatory requirements |
| [Claude Guide](CLAUDE.md) | AI assistant guidance |

## Common Commands

```bash
bin/rails server              # Start dev server
bundle exec rspec             # Run all tests
bin/rails smoke_test:all      # Quick integration check
bin/rails console             # Rails console
```

## Regulatory Compliance

This application handles sensitive personal data and must comply with UK/EU GDPR. The system uses **deterministic pattern matching** (not AI) to avoid EU AI Act High-Risk classification.

See [COMPLIANCE.md](COMPLIANCE.md) for full requirements.

## License

MIT License - see LICENSE file for details.
