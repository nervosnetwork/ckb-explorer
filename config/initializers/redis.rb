require "redis"
require "connection_pool"

redis_config = Rails.application.config_for(:redis)

$redis = ConnectionPool.new(size: 10) { Redis.new(url: redis_config["url"], driver: :hiredis, password: redis_config["password"]) }
