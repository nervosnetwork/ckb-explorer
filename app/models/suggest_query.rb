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
    Block.cached_find(query_key)
  end

  def find_ckb_transaction_by_hash
    ckb_transaction = CkbTransaction.cached_find(query_key)
    CkbTransactionSerializer.new(ckb_transaction) if ckb_transaction.present?
  end

  def find_cached_address
    address = Address.cached_find(query_key)
    return if address.blank?

    if QueryKeyUtils.valid_hex?(query_key)
      LockHashSerializer.new(address)
    else
      AddressSerializer.new(address)
    end
  end

  def find_by_hex
    find_cached_block || find_ckb_transaction_by_hash || find_cached_address
  end
end
