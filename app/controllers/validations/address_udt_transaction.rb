module Validations
  class AddressUdtTransaction
    include ActiveModel::Validations

    validate :type_hash_format_must_be_correct
    validate :address_hash_format_must_be_correct

    def initialize(params = {})
      @address_hash = params[:id]
      @type_hash = params[:type_hash]
    end

    def error_object
      api_errors = []

      if invalid?
        api_errors << Api::V1::Exceptions::TypeHashInvalidError.new if :type_hash.in?(errors.keys)
        api_errors << Api::V1::Exceptions::AddressHashInvalidError.new if :address_hash.in?(errors.keys)
        {
          status: api_errors.first.status,
          errors: RequestErrorSerializer.new(api_errors, message: api_errors.first.title)
        }
      end
    end

    private

    attr_accessor :type_hash, :address_hash

    def type_hash_format_must_be_correct
      if type_hash.blank? || !QueryKeyUtils.valid_hex?(type_hash)
        errors.add(:type_hash, "query key is invalid")
      end
    end

    def address_hash_format_must_be_correct
      errors.add(:address_hash, "query key is invalid") unless QueryKeyUtils.valid_address?(address_hash)
    end
  end
end
