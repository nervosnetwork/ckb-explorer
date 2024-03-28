class SuggestQuery
  def initialize(query_key)
    @query_key = query_key
  end

  def find!
    find_record_by_query_key!
  end

  private

  attr_reader :query_key

  def find_record_by_query_key!
    result =
      if QueryKeyUtils.integer_string?(query_key)
        find_cached_block
      elsif QueryKeyUtils.valid_hex?(query_key)
        find_by_hex
      elsif QueryKeyUtils.valid_address?(query_key)
        find_cached_address
      end

    raise ActiveRecord::RecordNotFound if result.blank?

    result
  end

  def find_cached_block
    block = Block.cached_find(query_key)
    raise Api::V1::Exceptions::BlockNotFoundError if block.blank?

    block
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
    raise Api::V1::Exceptions::AddressNotFoundError if address.blank?

    AddressSerializer.new(address)
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

  def find_by_hex
    Block.cached_find(query_key) ||
      find_ckb_transaction_by_hash ||
      find_address_by_lock_hash ||
      find_udt_by_type_hash ||
      find_type_script_by_type_id ||
      find_type_script_by_code_hash ||
      find_lock_script_by_code_hash ||
      find_bitcoin_transaction_by_txid
  end

  def find_bitcoin_transaction_by_txid
    txid = query_key.delete_prefix(Settings.default_hash_prefix)
    bitcoin_transaction = BitcoinTransaction.find_by(txid:)
    BitcoinTransactionSerializer.new(bitcoin_transaction) if bitcoin_transaction
  end
end
