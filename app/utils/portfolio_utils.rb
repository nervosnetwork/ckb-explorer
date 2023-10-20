module PortfolioUtils
  class << self
    def generate_jwt(payload)
      payload[:exp] ||= Time.current.to_i + ENV["AUTH_ACCESS_EXPIRE"].to_i
      JWT.encode(payload, ENV["SECRET_KEY_BASE"], "HS256")
    end
  end
end
