module CacheRealizer
  def realize(key, *args, &block)
    fetch(key, *args, &block).tap do |result|
      delete(key) if result.nil?
    end
  end
end

Rails.cache.extend(CacheRealizer)
