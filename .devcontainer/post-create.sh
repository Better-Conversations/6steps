#!/bin/bash
set -e

echo "🚀 Setting up Six Steps development environment..."

# Install Ruby dependencies
if [ -f Gemfile ]; then
  echo "📦 Installing Ruby gems..."
  bundle install
fi

# Install Node.js dependencies (if package.json exists)
if [ -f package.json ]; then
  echo "📦 Installing Node.js packages..."
  npm install
fi

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL..."
until pg_isready -h db -U postgres > /dev/null 2>&1; do
  sleep 1
done

# Setup database
echo "🗄️  Setting up database..."
bin/rails db:create db:migrate || true

# Install Claude
echo "🤖 Installing Claude..."
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' | sudo tee /etc/profile.d/claude.sh > /dev/null

echo "✅ Setup complete!"
echo ""
echo "To start the Rails server, run:"
echo "  bin/rails server"
echo ""
echo "The server will be available at http://localhost:3000"
