require "sidekiq/web"
require "sidekiq-unique-jobs"

redis_config = Rails.application.config_for(:redis)
redis_url = redis_config["url"]
redis_password = redis_config["password"]

Sidekiq.strict_args!(false)

Sidekiq.configure_server do |config|
  # config.redis = { url: redis_url, driver: :ruby, password: redis_password }
  config.redis = { url: redis_url, driver: :hiredis, password: redis_password }

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  SidekiqUniqueJobs::Server.configure(config)
end
Sidekiq.configure_client do |config|
  config.redis = { url: redis_url, driver: :hiredis, password: redis_password }
  # config.redis = { url: redis_url, driver: :ruby, password: redis_password }

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end

# Auth sidekiq user in production env.
if Rails.env.production?
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    # Protect against timing attacks:
    # - See https://codahale.com/a-lesson-in-timing-attacks/
    # - See https://thisdata.com/blog/timing-attacks-against-string-comparison/
    # - Use & (do not use &&) so that it doesn't short circuit.
    # - Use digests to stop length information leaking (see also ActiveSupport::SecurityUtils.variable_size_secure_compare)
    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username),
                                                ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])) &
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password),
                                                  ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"]))
  end
end
