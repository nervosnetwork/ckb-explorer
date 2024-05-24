class SuggestQuery
  attr_reader :query_key, :filter_by

  def initialize(query_key, filter_by = nil)
    @query_key = query_key
    @filter_by = filter_by
  end

  def find!
    if filter_by.present? && filter_by.to_i.zero?
      aggregate_query!
    else
      single_query!
    end
  end

  def single_query!
    result =
      if QueryKeyUtils.integer_string?(query_key)
        find_cached_block
      elsif QueryKeyUtils.valid_hex?(query_key)
        res = query_methods.map(&:call).compact
        return res.first if res.any?
      elsif QueryKeyUtils.valid_address?(query_key)
        find_cached_address
      end

    raise ActiveRecord::RecordNotFound if result.blank?

    result
  end

  def aggregate_query!
    results = Hash.new { |h| h[:data] = Array.new }

    # If query_key is all numbers, search block
    if QueryKeyUtils.integer_string?(query_key) && (block = find_cached_block).present?
      results[:data] << block.serializable_hash[:data]
      return results
    end

    # If the string length is less than 2, the query result will be empty
    raise ActiveRecord::RecordNotFound if query_key.length < 2

    if QueryKeyUtils.valid_hex?(query_key)
      query_methods.each { results[:data] << _1.call.serializable_hash[:data] if _1.call.present? }
    end
    if QueryKeyUtils.valid_address?(query_key) && (address = find_cached_address).present?
      results[:data] << address.serializable_hash[:data]
    end
    if (address = find_bitcoin_address).present?
      results[:data] << address.serializable_hash[:data]
    end
    if (udts = find_udts_by_name_or_symbol).present?
      results[:data].concat(udts.serializable_hash[:data])
    end
    if (collections = find_nft_collections_by_name).present?
      results[:data].concat(collections.serializable_hash[:data])
    end

    raise ActiveRecord::RecordNotFound if results.blank?

    results
  end

  def query_methods
    [
      method(:find_cached_block),
      method(:find_ckb_transaction_by_hash),
      method(:find_address_by_lock_hash),
      method(:find_udt_by_type_hash),
      method(:find_type_script_by_type_id),
      method(:find_type_script_by_code_hash),
      method(:find_lock_script_by_code_hash),
      method(:find_bitcoin_transaction_by_txid),
    ]
  end

  def find_cached_block
    Block.cached_find(query_key)
  end

  def find_ckb_transaction_by_hash
    ckb_transaction = CkbTransaction.cached_find(query_key)
    CkbTransactionSerializer.new(ckb_transaction) if ckb_transaction.present?
  end

  def find_address_by_lock_hash
    address = Address.cached_find(query_key)
    LockHashSerializer.new(address) if address.present?
  end

  def find_cached_address
    address = Address.cached_find(query_key)
    AddressSerializer.new(address) if address.present?
  end

  def find_udt_by_type_hash
    udt = Udt.find_by(type_hash: query_key, published: true)
    UdtSerializer.new(udt) if udt.present?
  end

  def find_type_script_by_type_id
    type_script = TypeScript.find_by(args: query_key, code_hash: Settings.type_id_code_hash)
    TypeScriptSerializer.new(type_script) if type_script.present?
  end

  def find_lock_script_by_code_hash
    lock_script = LockScript.find_by(code_hash: query_key)
    LockScriptSerializer.new(lock_script) if lock_script.present?
  end

  def find_type_script_by_code_hash
    type_script = TypeScript.find_by(code_hash: query_key)
    TypeScriptSerializer.new(type_script) if type_script.present?
  end

  def find_bitcoin_transaction_by_txid
    txid = query_key.delete_prefix(Settings.default_hash_prefix)
    bitcoin_transaction = BitcoinTransaction.find_by(txid:)
    BitcoinTransactionSerializer.new(bitcoin_transaction) if bitcoin_transaction
  end

  def find_udts_by_name_or_symbol
    udts = Udt.where(udt_type: %i[sudt xudt omiga_inscription], published: true).
      where("LOWER(full_name) LIKE LOWER(:query_key) OR LOWER(symbol) LIKE LOWER(:query_key)", query_key: "%#{query_key}%")
    UdtSerializer.new(udts) if udts.present?
  end

  def find_nft_collections_by_name
    token_collections = TokenCollection.where("LOWER(name) LIKE LOWER(:query_key)", query_key: "%#{query_key}%")
    TokenCollectionSerializer.new(token_collections) if token_collections.present?
  end

  def find_bitcoin_address
    bitcoin_address = BitcoinAddress.find_by(address_hash: query_key)
    BitcoinAddressSerializer.new(bitcoin_address) if bitcoin_address.present?
  end
end
