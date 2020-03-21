class AddressPresenter
  def initialize(object)
    @object = object.is_a?(Array) ? object : [object]
  end

  def id
    object.first.id
  end

  def address_hash
    object.first.query_address
  end

  def balance
    object.reduce(0) { |sum, addr| sum + addr.balance.to_i }
  end

  def dao_deposit
    object.reduce(0) { |sum, addr| sum + addr.dao_deposit.to_i }
  end

  def interest
    object.reduce(0) { |sum, addr| sum + addr.interest.to_i }
  end

  def live_cells_count
    object.reduce(0) { |sum, addr| sum + addr.live_cells_count.to_i }
  end

  def mined_blocks_count
    object.reduce(0) { |sum, addr| sum + addr.mined_blocks_count.to_i }
  end

  def lock_script
    object.first.cached_lock_script
  end

  def ckb_transactions_count
    ckb_transactions.count
  end

  def special?
    object.first.special?
  end

  def ckb_transactions
    ckb_transaction_ids = AccountBook.where(address_id: object.pluck(:id)).select(:ckb_transaction_id).distinct
    CkbTransaction.where(id: ckb_transaction_ids).recent
  end

  def ckb_dao_transactions
    address_ids = object.pluck(:id)
    ckb_transaction_ids = CellOutput.where(address_id: address_ids).where(cell_type: %w(nervos_dao_deposit nervos_dao_withdrawing)).select("ckb_transaction_id")
    CkbTransaction.where(id: ckb_transaction_ids)
  end

  def ckb_udt_transactions(type_hash)
    address_ids = object.pluck(:id)
    ckb_transaction_ids = CellOutput.udt.where(address_id: address_ids, type_hash: type_hash).pluck("generated_by_id") + CellOutput.udt.where(address_id: address_ids, type_hash: type_hash).pluck("consumed_by_id").compact
    CkbTransaction.where(id: ckb_transaction_ids.uniq)
  end

  def lock_info
    object.first.lock_script.lock_info
  end

  def average_deposit_time
    object.first.average_deposit_time
  end

  def udt_accounts
    object.first.udt_accounts
  end

  private

  attr_reader :object
end
