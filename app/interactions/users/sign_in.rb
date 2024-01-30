module Users
  class SignIn < ActiveInteraction::Base
    include Api::V2::Exceptions

    string :address, :message, :signature
    string :pub_key, default: nil

    validates :address, :message, :signature, presence: true
    validate :validate_params_format!
    validate :validate_signature!

    def execute
      user = User.find_or_create_by(identifier: address)
      jwt = PortfolioUtils.generate_jwt({ uuid: user.uuid })

      { name: user.name, jwt: }
    end

    private

    def validate_params_format!
      raise AddressNotMatchEnvironmentError.new(ENV["CKB_NET_MODE"]) unless QueryKeyUtils.valid_address?(address)
      raise InvalidPortfolioMessageError.new unless QueryKeyUtils.hex_string?(message)
      raise InvalidPortfolioSignatureError.new unless QueryKeyUtils.hex_string?(signature)
    end

    def validate_signature!
      verified = PortfolioSignatureVerifier.new(address, message, signature, pub_key).verified?
      raise InvalidPortfolioSignatureError.new unless verified
    end
  end
end
