# frozen_string_literal: true

if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

    # Filter out health check endpoint from transactions
    config.before_send_transaction = lambda do |event, _hint|
      return nil if event.transaction == "Rails: HealthCheck" || event.transaction&.include?("/up")
      event
    end

    # Filter out health check endpoint from traces sampling
    config.traces_sampler = lambda do |sampling_context|
      transaction_context = sampling_context[:transaction_context]
      transaction_name = transaction_context[:name]

      return 0.0 if transaction_name&.include?("/up")

      # Default sample rate for other transactions
      0.1
    end

    # Profile sample rate (profiles_sampler is not available in this version)
    config.profiles_sample_rate = 0.1

    # Add data like request headers and IP for users,
    # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
    config.send_default_pii = true

    # Enable sending logs to Sentry
    config.enable_logs = true
    # Patch Ruby logger to forward logs
    config.enabled_patches = [ :logger ]
  end
end
