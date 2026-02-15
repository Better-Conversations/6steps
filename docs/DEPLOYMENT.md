# Deployment Guide

**Last Updated:** 2026-02-03

---

## Quick Reference

| Item       | Value                               |
| ---------- | ----------------------------------- |
| Stack      | Rails 8.1+, PostgreSQL, Solid Queue |
| Ruby       | 3.4.4                               |
| Deployment | GitHub Actions → GHCR → Docker      |
| SSL        | Required (TLS 1.3)                  |
| Encryption | AES-256 via Rails credentials       |
| Web Server | Thruster (built into container)     |

---

## Environment Variables

### Core Rails Variables

| Variable                   | Required | Default           | Description                                                                          |
| -------------------------- | -------- | ----------------- | ------------------------------------------------------------------------------------ |
| `RAILS_ENV`                | Yes      | -                 | Environment (production, development, test)                                          |
| `RAILS_MASTER_KEY`         | Yes\*    | -                 | Decrypts Rails credentials. _Not required if using `ACTIVE*RECORD_ENCRYPTION*_` vars |
| `DATABASE_URL`             | No       | Uses database.yml | Full database connection URL (overrides database.yml)                                |
| `RAILS_SERVE_STATIC_FILES` | No       | false             | Enable static file serving (set to `true` for containerized deployments)             |
| `RAILS_LOG_TO_STDOUT`      | No       | false             | Log to stdout instead of files                                                       |
| `RAILS_LOG_LEVEL`          | No       | `info`            | Log level: debug, info, warn, error, fatal                                           |

### Web Server (Puma)

| Variable              | Required | Default | Description                                            |
| --------------------- | -------- | ------- | ------------------------------------------------------ |
| `PORT`                | No       | `3000`  | HTTP port Puma listens on                              |
| `RAILS_MAX_THREADS`   | No       | `3`     | Thread count per worker (also sets database pool size) |
| `WEB_CONCURRENCY`     | No       | `1`     | Number of Puma worker processes                        |
| `PIDFILE`             | No       | -       | Custom PID file location                               |
| `SOLID_QUEUE_IN_PUMA` | No       | -       | Set to run Solid Queue supervisor inside Puma          |

### Email (Postmark)

| Variable               | Required       | Default             | Description                                        |
| ---------------------- | -------------- | ------------------- | -------------------------------------------------- |
| `POSTMARK_API_TOKEN`   | **Yes** (prod) | -                   | Postmark API token for email delivery              |
| `MAILER_FROM_ADDRESS`  | No             | `noreply@localhost` | Default "from" address for emails                  |
| `APPLICATION_HOST`     | No             | `localhost`         | Host for URLs in emails (e.g., invite links)       |
| `APPLICATION_PORT`     | No             | -                   | Port for URLs in emails (omit for standard 80/443) |
| `APPLICATION_PROTOCOL` | No             | `https`             | Protocol for URLs in emails                        |

### Encryption

Encryption can be configured via Rails credentials OR environment variables. If using environment variables:

| Variable                                       | Required  | Default | Description                                  |
| ---------------------------------------------- | --------- | ------- | -------------------------------------------- |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`         | **Yes\*** | -       | 32-byte hex key for encrypting data          |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`   | **Yes\*** | -       | 32-byte hex key for deterministic encryption |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | **Yes\*** | -       | 32-byte hex salt for key derivation          |

\*Required only if not using Rails credentials for encryption keys.

### Monitoring

| Variable     | Required | Default | Description                                            |
| ------------ | -------- | ------- | ------------------------------------------------------ |
| `SENTRY_DSN` | No       | -       | Sentry DSN for error tracking. Omit to disable Sentry. |

### Admin Bootstrap

For initial deployment when no users exist:

| Variable         | Required | Default | Description                                         |
| ---------------- | -------- | ------- | --------------------------------------------------- |
| `ADMIN_EMAIL`    | No       | -       | Email for initial admin user                        |
| `ADMIN_PASSWORD` | No       | -       | Password for initial admin (6-128 chars)            |
| `ADMIN_REGION`   | No       | `uk`    | Region for crisis resources (uk, us, eu, au, other) |

These are only used when `User.count == 0` and the app boots. Run `bin/rails admin:create_initial` to create the admin user.

### CI/Test Only

| Variable | Required | Default | Description                                             |
| -------- | -------- | ------- | ------------------------------------------------------- |
| `CI`     | No       | -       | When present, enables eager loading in test environment |

---

## 5. Background Jobs

The application uses **Solid Queue** for background processing (database-backed, no Redis required).

### Required Jobs

| Job                | Schedule | Purpose                                   |
| ------------------ | -------- | ----------------------------------------- |
| `DataRetentionJob` | Daily    | GDPR data minimization (30-day redaction) |

### Running Jobs

Jobs are processed by Solid Queue workers. For scheduled jobs, set up a cron:

```cron
0 2 * * * cd /app && docker compose exec web bin/rails runner 'DataRetentionJob.perform_now' >> /var/log/sixsteps/retention.log 2>&1
```
