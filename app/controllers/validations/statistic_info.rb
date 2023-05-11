module Validations
  class StatisticInfo
    include ActiveModel::Validations

    validate :query_key_format_must_be_correct

    def initialize(params = {})
      @query_key = params[:id]
    end

    def error_object
      api_errors = []

      if invalid?
        api_errors << Api::V1::Exceptions::StatisticInfoNameInvalidError.new if :query_key.in?(errors.attribute_names)
        {
          status: api_errors.first.status,
          errors: RequestErrorSerializer.new(api_errors, message: api_errors.first.title)
        }
      end
    end

    private

    attr_accessor :query_key

    def query_key_format_must_be_correct
      if query_key.blank? || !valid_statistic_info_names.include?(query_key.to_sym)
        errors.add(:query_key, "statistic info name is invalid")
      end
    end

    def valid_statistic_info_names
      ::StatisticInfo.instance_methods(false) + ::StatisticInfo.column_names.map(&:to_sym)
    end
  end
end
