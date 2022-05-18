module RedisCachable
  extend ActiveSupport::Concern

  included do
    class << self
      alias_method(:temp_lock_method, :lock)
    end

    include Redis::Objects

    class << self
      alias_method(:redis_lock, :lock)
      alias_method(:lock, :temp_lock_method)
      remove_method(:temp_lock_method)
    end
  end
end
