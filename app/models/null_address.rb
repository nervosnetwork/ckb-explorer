class NullAddress
  attr_reader :address_hash

  def initialize(address_hash)
    @address_hash = address_hash
  end

  def id
    0
  end

  def balance
    0
  end

  def ckb_transactions_count
    0
  end

  def lock_hash; end

  def lock_info; end

  def cached_lock_script; end

  def pending_reward_blocks_count
    0
  end

  def dao_deposit
    0
  end

  def interest
    0
  end

  def lock_script
    script = CKB::AddressParser.new(address_hash).parse.script
    LockScript.new(code_hash: script.code_hash, args: script.args, hash_type: script.hash_type)
  end
end
