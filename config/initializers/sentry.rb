Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = %i[active_support_logger http_logger]
  config.logger = Logger.new(STDERR)
  config.enabled_environments = %w[production staging]
end
