FactoryBot.define do
  factory :contract do
    hash_type { "type" }
    deployed_args { "0x#{SecureRandom.hex(32)}" }
    name { "CKB COIN TEST" }
    symbol { "TTF" }
    description { "SECP256K1/multisig (Source Code) is a script which allows a group of users to sign a single transaction." }
    verified { false }
    deprecated { false }
    total_referring_cells_capacity { SecureRandom.random_number(10**10) }
    ckb_transactions_count { SecureRandom.random_number(10**10) }
    addresses_count { SecureRandom.random_number(100_000_000) }
    type_hash { "0x#{SecureRandom.hex(32)}" }
    is_type_script { true }
  end
end
