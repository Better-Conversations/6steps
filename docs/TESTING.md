# Testing Guide

This document covers testing practices and commands for Six Steps.

## Running Tests

```bash
# Run full test suite
bundle exec rspec

# Run smoke tests (quick integration check)
bin/rails smoke_test:all

# Run safety monitor tests (80+ tests)
bundle exec rspec spec/services/safety_monitor_spec.rb

# Run compliance tests (20 tests)
bundle exec rspec spec/compliance/

# Run with coverage
COVERAGE=true bundle exec rspec

# Security scan
bundle exec brakeman
```

## Test Categories

| Directory | Purpose | Critical? |
|-----------|---------|-----------|
| `spec/services/safety_monitor_spec.rb` | Crisis detection patterns | **Yes** |
| `spec/compliance/` | Regulatory requirements | **Yes** |
| `spec/models/` | Model validations | Yes |
| `spec/requests/` | Controller behaviour | Yes |
| `spec/features/` | End-to-end flows | Yes |

## Before Deploying Changes

1. Check if your changes affect compliance-sensitive files (see `COMPLIANCE.md`)
2. Run compliance tests: `bundle exec rspec spec/compliance/`
3. Run safety tests: `bundle exec rspec spec/services/safety_monitor_spec.rb`
4. Run security scan: `bundle exec brakeman`

## Test Database Setup

If tests fail with database errors:

```bash
bin/rails db:migrate RAILS_ENV=test
```

## Critical Tests

The following tests must pass before any deployment:

- **Safety Monitor tests** - Crisis detection patterns must work correctly
- **Compliance tests** - Regulatory requirements must be met

```bash
# Run critical tests only
bundle exec rspec spec/services/safety_monitor_spec.rb spec/compliance/
```
