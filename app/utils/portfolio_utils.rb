module PortfolioUtils
  class << self
    def generate_jwt(payload)
      payload[:exp] ||= Time.current.to_i + ENV["AUTH_ACCESS_EXPIRE"].to_i
      JWT.encode(payload, ENV["SECRET_KEY_BASE"], "HS256")
    end

    def decode_jwt(jwt)
      JWT.decode jwt, ENV["SECRET_KEY_BASE"], true, { algorithm: "HS256" }
    end
  end
end
