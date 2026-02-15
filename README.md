# Six Steps

A Rails application offering quiet spaces for self-reflection, using the Six Spaces technique inspired by David Grove's Emergent Knowledge.

Six Steps is a Rails 8.0+ application offering quiet spaces for self-reflection, using the Six Spaces technique inspired by David Grove's Emergent Knowledge. This is a tool for structured self-reflection - it is not intended as a substitute for professional coaching, counselling, or therapy.

## Quick Start using Docker

If you'd just like to try the application you can do so using Docker Compose.

1. Install the latest version of [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Download the `docker-compose.yml` from this repository to your local machine
3. Run `docker compose up` in the same directory
4. Wait for all services to start (the database health check will complete first)

Once running, access the application at:

| Service | URL | Description |
|---------|-----|-------------|
| Web App | http://localhost | Main application |
| Mailpit | http://localhost:8025 | Email capture UI - view all sent emails here |

The default admin credentials (created on first run) are:
- Email: `admin@localhost`
- Password: `change_me_immediately`

To stop the application, press `Ctrl+C` or run `docker compose down`.

The `docker-compose.yml` includes sensible defaults for local testing. For production deployment, see the "Hosting this yourself" section below.

## Developing

If you want to develop/extend the application:

- Fork the repository on GitHub
- Clone the repository to your local machine
- Open in Dev Container (e.g. VS Code or Cursor)
- Claude code is installed in the container for your AI assistant needs
- Enjoy!
- We welcome contributions to the project by raising issues, feature requests, or pull requests.

## Hosting this yourself

You're welcome to host this yourself. Start from the `docker-compose.yml` file and:

- Generate secure values for `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`, and the encryption keys
- Set `FORCE_SSL=true` and configure your SSL termination (reverse proxy)
- Set `APPLICATION_HOST` to your domain and `APPLICATION_PROTOCOL=https`
- For email delivery, either:
  - Remove `SMTP_ADDRESS` and `SMTP_PORT`, then set `POSTMARK_API_TOKEN` for Postmark delivery, or
  - Configure `SMTP_ADDRESS` and `SMTP_PORT` for your own SMTP server
- Optionally set `SENTRY_DSN` for error monitoring
- Optionally set `UMAMI_WEBSITE_ID` for privacy-friendly analytics via [Umami](https://umami.is)
- Update the admin bootstrap credentials (`ADMIN_EMAIL`, `ADMIN_PASSWORD`)

## License

MIT License - see LICENSE file for details.
