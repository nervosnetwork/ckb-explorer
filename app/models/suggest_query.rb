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
        find_block
      elsif QueryKeyUtils.valid_hex?(query_key)
        find_by_hex
      elsif QueryKeyUtils.valid_address?(query_key)
        find_address
      end

    raise ActiveRecord::RecordNotFound if result.blank?

    result
  end

  def find_block
    block = Block.direct_find(query_key)
    raise Api::V1::Exceptions::BlockNotFoundError if block.blank?

    block
  end

  def find_ckb_transaction_by_hash
    ckb_transaction = CkbTransaction.find(query_key)
    CkbTransactionSerializer.new(ckb_transaction) if ckb_transaction.present?
  end

  def find_address_by_lock_hash
    address = Address.direct_find(query_key)
    LockHashSerializer.new(address) if address.present?
  end

  def find_address
    address = Address.direct_find(query_key)
    raise Api::V1::Exceptions::AddressNotFoundError if address.blank?

    AddressSerializer.new(address)
  end

  def find_udt_by_type_hash
    udt = Udt.find_by(type_hash: query_key, published: true)
    UdtSerializer.new(udt) if udt.present?
  end

  def find_pool_tx_by_hash
    tx = PoolTransactionEntry.find_by(tx_hash: query_key)
    CkbTransactionSerializer.new(tx) if tx.present?
  end

  def find_by_hex
    Block.direct_find(query_key) || find_ckb_transaction_by_hash || find_pool_tx_by_hash || find_address_by_lock_hash || find_udt_by_type_hash
  end
end
