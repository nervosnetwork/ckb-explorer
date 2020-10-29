FactoryBot.define do
  factory :pool_transaction_entry do
    tx_hash { "0x#{SecureRandom.hex(32)}" }
  end
end
