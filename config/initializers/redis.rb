require "redis"

redis_config = Rails.application.config_for(:redis)

$redis = Redis.new(url: redis_config["url"], driver: :ruby, password: redis_config["password"])
#$redis = Redis.new(url: redis_config["url"], driver: :hiredis, password: redis_config["password"])
