module Validations
  class BlockTransaction
    include ActiveModel::Validations

    validate :query_key_format_must_be_correct

    def initialize(params = {})
      @query_key = params[:id]
    end

    def error_object
      api_errors = []

      if invalid?
        api_errors << Api::V1::Exceptions::BlockHashInvalidError.new if :query_key.in?(errors.keys)
        {
          status: api_errors.first.status,
          errors: RequestErrorSerializer.new(api_errors, message: api_errors.first.title)
        }
      end
    end

    private

    attr_accessor :query_key

    def query_key_format_must_be_correct
      if query_key.blank? || !QueryKeyUtils.valid_hex?(query_key)
        errors.add(:query_key, "query key is invalid")
      end
    end
  end
end
