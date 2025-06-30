FactoryBot.define do
  factory :contract do
    hash_type { "type" }
    deployed_args { "0x#{SecureRandom.hex(32)}" }
    name { "CKB COIN TEST" }
    description { "SECP256K1/multisig (Source Code) is a script which allows a group of users to sign a single transaction." }
    verified { true }
    deprecated { false }
    total_referring_cells_capacity { SecureRandom.random_number(10**10) }
    ckb_transactions_count { SecureRandom.random_number(10**10) }
    addresses_count { SecureRandom.random_number(100_000_000) }
    type_hash { "0x#{SecureRandom.hex(32)}" }
    is_type_script { true }
    dep_type { "code" }
    is_zero_lock { false }
    deployed_block_timestamp { Time.now.to_i * 1000 }

    after(:build) do |contract, _evaluator|
      if contract.deployed_cell_output_id.nil?
        output = create(:cell_output, :with_full_transaction)
        contract.deployed_cell_output_id = output.id
      end
    end
  end
end
