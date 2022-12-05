module QueryKeyUtils
  class << self
    def integer_string?(query_key)
      /\A\d+\z/.match?(query_key)
    end

    def valid_hex?(query_key)
      start_with_default_hash_prefix?(query_key) && length_is_valid?(query_key) && hex_string?(query_key)
    end

    def start_with_default_hash_prefix?(query_key)
      query_key.start_with?(Settings.default_hash_prefix)
    end

    def length_is_valid?(query_key)
      query_key.length == Settings.default_with_prefix_hash_length.to_i
    end

    def hex_string?(query_key)
      !query_key.delete_prefix(Settings.default_hash_prefix)[/\H/]
    end

    def valid_address?(query_key)
      CkbUtils.parse_address(query_key) rescue nil
    end
  end
end
