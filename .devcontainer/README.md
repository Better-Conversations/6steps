# DevContainer Setup

This directory contains the configuration for using Visual Studio Code Dev Containers with the Six Steps Rails application.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop) (or Docker Engine + Docker Compose)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

## Getting Started

1. Open the project in VS Code
2. When prompted, click "Reopen in Container" (or use Command Palette: `Dev Containers: Reopen in Container`)
3. Wait for the container to build and start (first time may take a few minutes)
4. The post-create script will automatically:
   - Install Ruby gems
   - Set up the PostgreSQL database
   - Run migrations

## What's Included

- **Ruby 3.4.4** - Matching your production environment
- **PostgreSQL 15** - Database server running in a separate container
- **Node.js & npm** - For Tailwind CSS compilation
- **Development tools** - Git, vim, build essentials
- **VS Code extensions** - Ruby LSP, Tailwind CSS, Prettier, etc.

## Database

The PostgreSQL database is automatically configured:
- Host: `db` (service name)
- Port: `5432`
- User: `postgres`
- Password: `postgres`
- Database: `six_steps_development`

The database persists in a Docker volume, so your data will survive container rebuilds.

## Running the Application

Once the container is ready:

```bash
# Start the Rails server
bin/rails server

# The server will be available at http://localhost:3000
```

## Port Forwarding

The following ports are automatically forwarded:
- `3000` - Rails server
- `5432` - PostgreSQL (for external database tools)

## Troubleshooting

### Container won't start
- Ensure Docker Desktop is running
- Check Docker has enough resources allocated (4GB+ RAM recommended)

### Database connection errors
- Wait a few seconds for PostgreSQL to fully start
- Check the database is healthy: `docker compose ps` (from host)

### Gems not installing
- Check your internet connection
- Try rebuilding the container: `Dev Containers: Rebuild Container`

### Need to reset the database
```bash
bin/rails db:drop db:create db:migrate
```

## Customization

Edit `.devcontainer/devcontainer.json` to:
- Add more VS Code extensions
- Change port forwarding
- Modify environment variables
- Add additional services

Edit `.devcontainer/Dockerfile` to:
- Install additional system packages
- Configure development tools
