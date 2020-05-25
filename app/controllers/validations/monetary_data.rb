module Validations
  class MonetaryData
    include ActiveModel::Validations

    validate :query_key_format_must_be_correct

    def initialize(params = {})
      @query_key = params[:id]
    end

    def error_object
      api_errors = []

      if invalid?
        api_errors << Api::V1::Exceptions::IndicatorNameInvalidError.new if :query_key.in?(errors.keys)
        {
          status: api_errors.first.status,
          errors: RequestErrorSerializer.new(api_errors, message: api_errors.first.title)
        }
      end
    end

    private

    attr_accessor :query_key

    def query_key_format_must_be_correct
      if query_key.blank? || !query_key_valid?
        errors.add(:query_key, "indicator name is invalid")
      end
    end

    def query_key_valid?
      query_keys = query_key.split("-")
      extra_keys = query_keys - ::MonetaryData::VALID_INDICATORS
      extra_keys.blank? || extra_keys.size == 1 && extra_keys.first =~ /^nominal_apc(\d+)$/
    end
  end
end
