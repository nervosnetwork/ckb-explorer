module Validations
  class Script
    include ActiveModel::Validations

    validate :is_hash_type_valid, :is_code_hash_valid

    def initialize(params = {})
      puts "== in initialize, params: #{params.inspect}"
      @hash_type = params[:hash_type]
      @code_hash = params[:code_hash]
    end

    def is_hash_type_valid
      if @hash_type != 'type'
        errors.add(:hash_type, "hash_type is invalid")
      end
    end

    def is_code_hash_valid
      if @code_hash.blank? || !QueryKeyUtils.valid_hex?(@code_hash)
        errors.add(:code_hash, "code_hash is invalid")
      end
    end

    def error_object
      api_errors = []

      if invalid?
        api_errors << Api::V1::Exceptions::ScriptCodeHashParamsInvalidError.new if :code_hash.in?(errors.attribute_names)
        api_errors << Api::V1::Exceptions::ScriptHashTypeParamsInvalidError.new if :hash_type.in?(errors.attribute_names)

        {
          status: api_errors.first.status,
          errors: RequestErrorSerializer.new(api_errors, message: api_errors.first.title)
        }
      end
    end

    private

    attr_accessor :code_hash, :hash_type
  end
end
