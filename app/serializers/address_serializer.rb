class AddressSerializer
  include FastJsonapi::ObjectSerializer

  attributes :address_hash, :balance, :lock_script, :transactions_count, :pending_reward_blocks_count
end
