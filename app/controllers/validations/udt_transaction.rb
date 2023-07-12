module Validations
  class UdtTransaction
    include ActiveModel::Validations

    validate :type_hash_format_must_be_correct
    validate :address_hash_format_must_be_correct
    validate :tx_hash_format_must_be_correct

    def initialize(params = {})
      @type_hash = params[:id]
      @address_hash = params[:address_hash]
      @tx_hash = params[:tx_hash]
    end

    def error_object
      api_errors = []

      if invalid?
        api_errors << Api::V1::Exceptions::TypeHashInvalidError.new if :type_hash.in?(errors.attribute_names)
        api_errors << Api::V1::Exceptions::AddressHashInvalidError.new if :address_hash.in?(errors.attribute_names)
        api_errors << Api::V1::Exceptions::CkbTransactionTxHashInvalidError.new if :tx_hash.in?(errors.attribute_names)

        {
          status: api_errors.first.status,
          errors: RequestErrorSerializer.new(api_errors, message: api_errors.first.title)
        }
      end
    end

    private

    attr_accessor :type_hash, :address_hash, :tx_hash

    def type_hash_format_must_be_correct
      if type_hash.blank? || !QueryKeyUtils.valid_hex?(type_hash)
        errors.add(:type_hash, "query key is invalid")
      end
    end

    def address_hash_format_must_be_correct
      if address_hash.present? && !QueryKeyUtils.valid_address?(address_hash)
        errors.add(:address_hash, "query key is invalid")
      end
    end

    def tx_hash_format_must_be_correct
      if tx_hash.present? && !QueryKeyUtils.valid_hex?(tx_hash)
        errors.add(:tx_hash, "query key is invalid")
      end
    end
  end
end
