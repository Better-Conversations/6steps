#!/bin/bash
set -e

# This script runs every time the container starts
# Useful for ensuring services are ready

# Wait for PostgreSQL
until pg_isready -h db -U postgres > /dev/null 2>&1; do
  sleep 1
done

echo "✅ PostgreSQL is ready"
