# Administration Guide

This document covers user management and administrative tasks for Six Steps.

## User Roles

| Role | Access | Typical Use |
|------|--------|-------------|
| `user` | Reflection sessions, own data | End users |
| `session_reviewer` | + Admin dashboard (anonymized) | Session oversight |
| `admin` | + Invite management, full access | Administrators |

## Quick Start by Role

### For Administrators

1. Log in with your admin credentials
2. Go to **Admin → Invites** to create invite links for new users
3. Go to **Admin → Dashboard** to review anonymized session metrics
4. Manage user roles via Rails console if needed (see below)

### For Session Reviewers

1. Log in with your session reviewer credentials
2. Access the **Admin Dashboard** to view:
   - Anonymized session metrics
   - Safety event summaries
   - Crisis activation rates
3. Note: You cannot see user identities or verbatim content—only patterns and aggregated data

### For End Users

1. Receive an invite link from an administrator
2. Register with your email and select your region (for crisis resources)
3. Complete the consent forms (required for GDPR compliance)
4. Start a reflection session from your dashboard

## Creating Invites

1. Log in as admin
2. Navigate to **Admin → Invites**
3. Click "Create Invite"
4. Optionally restrict to specific email
5. Share the generated URL

Invites expire after 7 days by default.

## Changing User Roles

```bash
bin/rails console
```

```ruby
# Promote to admin
User.find_by(email: "user@example.com").update!(role: :admin)

# Set as session reviewer
User.find_by(email: "reviewer@example.com").update!(role: :session_reviewer)

# Check a user's role
User.find_by(email: "user@example.com").role
```

## First Admin User

Since registration is invite-only, the first admin user must be created via console:

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

## Consent Requirements

Users must complete all four consent forms before starting sessions:

- Terms of Service
- Privacy Policy
- Sensitive Data Processing
- Session Reflections

Navigate to `/consents` to complete them.
