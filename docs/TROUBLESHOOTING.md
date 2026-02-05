# Troubleshooting Guide

This document covers common issues and their solutions for Six Steps.

## Encryption Issues

### "Encryption key is missing"

```bash
# Generate and add encryption keys
bin/rails db:encryption:init
EDITOR=vim bin/rails credentials:edit
```

Add the keys under `active_record_encryption`:

```yaml
active_record_encryption:
  primary_key: <generated_key>
  deterministic_key: <generated_key>
  key_derivation_salt: <generated_salt>
```

## Database Issues

### "PG::ConnectionBad: could not connect to server"

```bash
# Check PostgreSQL is running
pg_isready

# On macOS with Homebrew:
brew services start postgresql@15
```

## User & Session Issues

### "Can't start session - consent required"

Users must complete all four consent forms before starting sessions:
- Terms of Service
- Privacy Policy
- Sensitive Data Processing
- Session Reflections

Navigate to `/consents` to complete them.

### "Invite is invalid or expired"

Invites expire after 7 days by default. Ask an admin to create a new invite.

### "Role not found" or permission errors

Check user role in console:

```ruby
User.find_by(email: "user@example.com").role
```

## Test Issues

### Tests failing with "SafetyMonitor" errors

Ensure you've run migrations:

```bash
bin/rails db:migrate RAILS_ENV=test
```

### Tests failing with database errors

Reset the test database:

```bash
bin/rails db:drop db:create db:migrate RAILS_ENV=test
```

## Development Issues

### Assets not compiling

```bash
# Rebuild Tailwind CSS
bin/rails tailwindcss:build
```

### Credentials file issues

```bash
# Edit credentials
EDITOR=vim bin/rails credentials:edit

# If master.key is missing, you'll need to recreate credentials
# (contact team lead for production keys)
```
