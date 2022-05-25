Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Set tracesSampleRate to 1.0 to capture 100%
  # of transactions for performance monitoring.
  # We recommend adjusting this value in production
  config.traces_sample_rate = ENV.fetch("SENTRY_SAMPLE_RATE", 1.0).to_f
  config.traces_sampler = lambda do |context|
    true
  end    
  config.logger = Logger.new(STDERR)
  config.enabled_environments = %w[production staging]
end
