FactoryBot.define do
  factory :contract do
    code_hash { "0x#{SecureRandom.hex(32)}" }
    hash_type { "type" }
    deployed_args { "0x#{SecureRandom.hex(32)}" }
    role { "type_script" }
    name { "CKB COIN TEST" }
    symbol { "TTF" }
    description { "SECP256K1/multisig (Source Code) is a script which allows a group of users to sign a single transaction." }
    verified { false }
    deprecated { false }
    after(:create) do |contract, _eval|
      tx = create :ckb_transaction, :with_single_output
      co = tx.cell_outputs.first
      case contract.hash_type
      when "type"
        co.create_type_script code_hash: "0x00000000000000000000000000000000000000000000000000545950455f4944", hash_type: "type", script_hash: contract.code_hash
      when "data"
        co.update data_hash: contract.code_hash
      end
      script = create :script, contract_id: contract.id, is_contract: true
      contract.deployed_cells.create cell_output_id: co.id
    end
  end
end
