# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t six_steps .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name six_steps six_steps

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.4
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Build cache proxies (optional - set via Kamal build args when 192.168.13.3 is available)
ARG APT_PROXY
ARG HTTP_PROXY
ARG NPM_REGISTRY

# Rails app lives here
WORKDIR /rails

# Install base packages (with optional APT proxy)
RUN if [ -n "$APT_PROXY" ]; then \
      echo "Acquire::http::Proxy \"$APT_PROXY\";" > /etc/apt/apt.conf.d/00proxy; \
    fi && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    rm -f /etc/apt/apt.conf.d/00proxy

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Re-declare build args for this stage
ARG APT_PROXY
ARG HTTP_PROXY
ARG NPM_REGISTRY

# Install packages needed to build gems (with optional APT proxy)
RUN if [ -n "$APT_PROXY" ]; then \
      echo "Acquire::http::Proxy \"$APT_PROXY\";" > /etc/apt/apt.conf.d/00proxy; \
    fi && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    rm -f /etc/apt/apt.conf.d/00proxy

# Set HTTP proxy for gem downloads and other network operations
ENV http_proxy=${HTTP_PROXY} \
    https_proxy=${HTTP_PROXY} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTP_PROXY}

# Set NPM registry if provided (for any npm/yarn operations)
ENV NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
