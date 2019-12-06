class AddressPresenter
  def initialize(object)
    @object = object.is_a?(Array) ? object : [object]
  end

  def id
    object.first.id
  end

  def address_hash
    object.first.address_hash
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

  def pending_reward_blocks_count
    [object.reduce(0) { |sum, addr| sum + addr.pending_reward_blocks_count }, 0].max
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

  def lock_info
    object.first.lock_script.lock_info
  end

  private

  attr_reader :object
end
