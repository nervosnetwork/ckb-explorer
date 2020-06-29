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

  def lock_info
    parsed_address = CKB::AddressParser.new(address_hash).parse
    LockScript.new(args: parsed_address.script.args, code_hash: parsed_address.script.code_hash).lock_info
  end

  def dao_deposit
    0
  end

  def interest
    0
  end

  def special?
    Settings.special_addresses[address_hash].present?
  end

  def live_cells_count
    0
  end

  def mined_blocks_count
    0
  end

  def lock_script
    @lock_script ||=
      begin
        parsed_address = CKB::AddressParser.new(address_hash).parse
        raise Api::V1::Exceptions::AddressNotMatchEnvironmentError.new(ENV["CKB_NET_MODE"]) if parsed_address.mode != ENV["CKB_NET_MODE"]

        script = parsed_address.script
        LockScript.new(code_hash: script.code_hash, args: script.args, hash_type: script.hash_type)
      end
  end

  def average_deposit_time
    0
  end

  def udt_accounts
    []
  end

  alias_method :cached_lock_script, :lock_script
end
