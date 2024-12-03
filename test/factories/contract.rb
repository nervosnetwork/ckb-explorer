FactoryBot.define do
  factory :contract do
    hash_type { "type" }
    deployed_args { "0x#{SecureRandom.hex(32)}" }
    role { "type_script" }
    name { "CKB COIN TEST" }
    symbol { "TTF" }
    description { "SECP256K1/multisig (Source Code) is a script which allows a group of users to sign a single transaction." }
    verified { false }
    deprecated { false }
    total_referring_cells_capacity { SecureRandom.random_number(10**10) }
    ckb_transactions_count { SecureRandom.random_number(10**10) }
    addresses_count { SecureRandom.random_number(100_000_000) }
    type_hash { "0x#{SecureRandom.hex(32)}" }

    after(:create) do |contract, _eval|
      tx = create :ckb_transaction, :with_single_output
      co = tx.cell_outputs.first
      case contract.hash_type
      when "type"
        co.create_type_script code_hash: "0x00000000000000000000000000000000000000000000000000545950455f4944", hash_type: "type", script_hash: contract.type_hash
      when "data"
        co.update data_hash: contract.code_hash
      end
      contract.deployed_cell_output_id = co.id
      contract.save
    end
  end
end
