module Validations
  class PortfolioSignature
    include ActiveModel::Validations

    validate :address_format_must_be_correct
    validate :message_format_must_be_correct
    validate :signature_format_must_be_correct
    validate :signature_must_be_valid

    def initialize(params = {})
      @address = params[:address]
      @message = params[:message]
      @signature = params[:signature]
      @pub_key = params[:pub_key]
    end

    def error_object
      api_errors = []

      if invalid?
        api_errors << Api::V2::Exceptions::AddressNotMatchEnvironmentError.new(ENV["CKB_NET_MODE"]) if :address.in?(errors.attribute_names)
        api_errors << Api::V2::Exceptions::InvalidPortfolioMessageError.new if :message.in?(errors.attribute_names)
        api_errors << Api::V2::Exceptions::InvalidPortfolioSignatureError.new if :signature.in?(errors.attribute_names)

        {
          status: api_errors.first.status,
          errors: RequestErrorSerializer.new(api_errors, message: api_errors.first.title)
        }
      end
    end

    private

    attr_accessor :address, :message, :signature, :pub_key

    def address_format_must_be_correct
      if address.blank? || !QueryKeyUtils.valid_address?(address)
        errors.add(:address, "address is invalid")
      end
    end

    def message_format_must_be_correct
      if message.blank? || !QueryKeyUtils.hex_string?(message)
        errors.add(:message, "message is invalid")
      end
    end

    def signature_format_must_be_correct
      if signature.blank? || !QueryKeyUtils.hex_string?(signature)
        errors.add(:signature, "signature is invalid")
      end
    end

    def signature_must_be_valid
      return if errors.present?

      signature_valid = PortfolioSignatureVerifier.new(address, message, signature, pub_key).verified?
      unless signature_valid
        errors.add(:signature, "signature is invalid")
      end
    end
  end
end
