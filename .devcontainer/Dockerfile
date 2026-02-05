# Development Dockerfile for DevContainer
ARG RUBY_VERSION=3.4.4
FROM docker.io/library/ruby:${RUBY_VERSION}-slim

# Install dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    curl \
    libpq-dev \
    libvips \
    libjemalloc2 \
    libyaml-dev \
    postgresql-client \
    nodejs \
    npm \
    vim \
    sudo \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Create vscode user (matching DevContainer convention)
RUN groupadd --gid 1000 vscode && \
    useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash vscode && \
    echo 'vscode ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set working directory
WORKDIR /workspace

# Install bundler
RUN gem install bundler

# Set environment variables
ENV RAILS_ENV=development
ENV BUNDLE_PATH=/usr/local/bundle
ENV BUNDLE_WITHOUT=""

# Enable jemalloc when available (arch-safe)
RUN printf '%s\n' \
  'if [ -z "${LD_PRELOAD+x}" ]; then' \
  '  JEMALLOC_PATH="$(find /usr/lib -name libjemalloc.so.2 -print -quit)"' \
  '  if [ -n "$JEMALLOC_PATH" ]; then' \
  '    export LD_PRELOAD="$JEMALLOC_PATH"' \
  '  fi' \
  'fi' \
  > /etc/profile.d/jemalloc.sh

# Switch to vscode user
USER vscode

# Default command
CMD ["sleep", "infinity"]
