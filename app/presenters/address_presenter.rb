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

  def lock_script
    object.first.cached_lock_script
  end

  def pending_reward_blocks_count
    [object.reduce(0) { |sum, addr| sum + addr.pending_reward_blocks_count }, 0].max
  end

  def transactions_count
    object.reduce(0) { |sum, addr| sum + addr.ckb_transactions_count }
  end

  def ckb_transactions
    CkbTransaction.joins(:account_books).where("account_books.address_id in (?)", object.pluck(:id)).recent.distinct
  end

  private

  attr_reader :object
end
