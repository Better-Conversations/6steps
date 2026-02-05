# Deployment Guide

**Last Updated:** 2026-02-03

---

## Quick Reference

| Item | Value |
|------|-------|
| Stack | Rails 8.0+, PostgreSQL, Solid Queue |
| Ruby | 3.4.4 |
| Deployment | GitHub Actions → GHCR → Docker |
| SSL | Required (TLS 1.3) |
| Encryption | AES-256 via Rails credentials |
| Web Server | Thruster (built into container) |

---

## 1. Deployment Process

**Note:** Deployment commands are for humans only. AI agents should direct users to read this file.

### Deploy a New Version

1. Check code into GitHub and wait for CI Actions to finish
2. SSH to the server:
   ```bash
   ssh apps@sixsteps-common.anteater-catfish.ts.net
   ```
3. Change to the app directory:
   ```bash
   cd rails-app
   ```
4. Refresh the app:
   ```bash
   ./refresh.sh
   ```

This pulls the new Docker image and restarts the server. Database migrations are handled automatically by the container entrypoint.

### Useful Commands

```bash
# Rails console on server
docker compose exec web bundle exec rails console

# View logs
docker compose logs -f web

# Check container status
docker compose ps
```

---

## 2. Infrastructure

### Current Setup

- **Server:** Proxmox VM on Tailscale (`sixsteps-common.anteater-catfish.ts.net`)
- **User:** `apps`
- **Database:** PostgreSQL (username/password: sixsteps/sixsteps)
- **Container Registry:** GitHub Container Registry (ghcr.io)

### CI/CD Pipeline

1. Push to `main` triggers GitHub Actions
2. Actions run security scans (Brakeman, importmap audit)
3. Docker image built and pushed to GHCR
4. Manual deployment via `refresh.sh` on server

---

## 3. Compliance Requirements

This application handles **sensitive personal data** under UK/EU GDPR. Hosting decisions have regulatory implications.

### Data Location

| Requirement | Reason |
|-------------|--------|
| UK or EU hosting preferred | Simplifies GDPR compliance |
| If US hosting | Requires Standard Contractual Clauses (SCCs) |
| Document location in privacy policy | GDPR transparency requirement |

### Encryption Requirements

| Layer | Requirement |
|-------|-------------|
| In Transit | TLS 1.3 (mandatory) |
| At Rest | AES-256 (handled by Rails) |
| Backups | Must be encrypted |
| Database | PostgreSQL with encryption at rest |

### Data Processing Agreement (DPA)

You must have a DPA in place with:
- Hosting provider
- Any backup service
- Any monitoring service (if it can access logs)

---

## 4. Environment Variables

### Required for Production

```bash
RAILS_ENV=production
RAILS_MASTER_KEY=<from credentials>
DATABASE_URL=postgres://sixsteps:sixsteps@localhost:5432/sixsteps_production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
```

### Credentials Setup

Encryption keys must be in Rails credentials:

```bash
EDITOR=vim bin/rails credentials:edit --environment production
```

Required keys:
```yaml
active_record_encryption:
  primary_key: <32-byte hex>
  deterministic_key: <32-byte hex>
  key_derivation_salt: <32-byte hex>
```

---

## 5. Background Jobs

The application uses **Solid Queue** for background processing (database-backed, no Redis required).

### Required Jobs

| Job | Schedule | Purpose |
|-----|----------|---------|
| `DataRetentionJob` | Daily | GDPR data minimization (30-day redaction) |

### Running Jobs

Jobs are processed by Solid Queue workers. For scheduled jobs, set up a cron:

```cron
0 2 * * * cd /app && docker compose exec web bin/rails runner 'DataRetentionJob.perform_now' >> /var/log/sixsteps/retention.log 2>&1
```

---

## 6. Security Hardening

### Server Setup

- [ ] Automatic security updates enabled
- [ ] UFW firewall configured (ports 22, 80, 443 only)
- [ ] Fail2ban installed and configured
- [ ] SSH key authentication only (password auth disabled)
- [ ] Non-root deployment user

### SSL/TLS

- [ ] TLS 1.3 enforced
- [ ] HSTS header enabled
- [ ] SSL certificate auto-renewal
- [ ] Strong cipher suites only

### Database

- [ ] Database not exposed to public internet
- [ ] Strong database password
- [ ] Regular backups (encrypted)
- [ ] Backup restoration tested

---

## 7. Monitoring

### Required Monitoring

| What | Why |
|------|-----|
| Uptime | User access to crisis resources |
| Error rates | Application health |
| SSL expiry | Security compliance |
| Disk space | Prevent outages |
| Failed login attempts | Security |

### Recommended Tools

- **Error tracking:** Sentry (configured in Gemfile)
- **Uptime:** UptimeRobot, Pingdom

### Log Retention

- Application logs: 30 days minimum
- Access logs: 30 days minimum
- Audit logs: Preserved indefinitely (SafetyAuditLog in database)

**Note:** Logs may contain PII - treat as sensitive data.

---

## 8. Backup Requirements

### What to Backup

| Item | Frequency | Retention |
|------|-----------|-----------|
| PostgreSQL database | Daily | 30 days |
| Rails credentials | On change | Indefinite (secure location) |
| SSL certificates | On renewal | Previous version |

### Backup Security

- All backups must be encrypted
- Store in separate location from primary
- Test restoration quarterly

---

## 9. Data Breach Notification

**CRITICAL:** Under GDPR Article 33, breaches must be reported to the ICO within 72 hours.

### Breach Detection

Monitor for:
- Unauthorized access attempts (fail2ban alerts)
- Unusual database queries
- Unexpected data exports
- Compromised credentials

### Escalation Process

1. **Detect breach** → Immediately notify Data Controller (Chandima)
2. **Assess scope** → Determine what data was affected
3. **Notify ICO** → Within 72 hours if personal data at risk
4. **Notify users** → If high risk to their rights

### ICO Contact

- **Online:** https://ico.org.uk/for-organisations/report-a-breach/
- **Phone:** 0303 123 1113

---

## 10. Crisis Resource Verification

**User Safety Requirement:** Crisis helpline numbers must be verified quarterly.

### Verification Schedule

| Quarter | Deadline |
|---------|----------|
| Q1 | March 31 |
| Q2 | June 30 |
| Q3 | September 30 |
| Q4 | December 31 |

### What to Verify

For each region (UK, US, EU, AU):
- Primary helpline number works
- Secondary helpline number works
- URLs resolve correctly
- Information is current

**File to update:** `app/services/crisis_resources.rb`

**Any changes require safety review before deployment.**

---

## 11. Incident Response

### Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| P1 | Service down, crisis resources unavailable | Immediate |
| P2 | Major feature broken | 4 hours |
| P3 | Minor issue | 24 hours |
| P4 | Enhancement | Scheduled |

### P1 Incident Procedure

1. Restore service (prioritize crisis resources page)
2. Notify Data Controller immediately
3. Document incident
4. Post-incident review within 48 hours

---

## 12. Pre-Deployment Checklist

Before every deployment:

```bash
# Security scan
bundle exec brakeman

# Compliance tests
bundle exec rspec spec/compliance/

# Full test suite
bundle exec rspec
```

**Do not deploy if any compliance tests fail.**

---

## 13. Contact Information

| Role | Contact |
|------|---------|
| Data Controller | Chandima |
| Technical Lead / Hosting | Simon Coles |

---

## 14. Outstanding Items

### Before Production (HIGH)

- [ ] Confirm hosting location and update privacy policy
- [ ] Obtain DPAs from hosting provider
- [ ] Set up breach notification escalation contacts
- [ ] Configure crisis resource verification calendar

### Before Public Launch (MEDIUM)

- [ ] Add cookie consent notice
- [ ] Document all sub-processors in COMPLIANCE.md
- [ ] Complete international transfer documentation (if applicable)

See `COMPLIANCE.md` for full regulatory requirements.
