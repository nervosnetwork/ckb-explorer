FactoryBot.define do
  factory :udt do
    code_hash { "0x#{SecureRandom.hex(32)}" }
    type_hash { "0x#{SecureRandom.hex(32)}" }
    hash_type { "type" }
    args { "0x#{SecureRandom.hex(20)}" }
    udt_type { "sudt" }
    full_name { "kingdom fat coin" }
    symbol { "kfc" }
    decimal { 6 }
    h24_ckb_transactions_count { 0 }

    trait :with_transactions do
      after(:create) do |udt, _evaluator|
        full_udt_address_ids = []
        20.times do
          block = create(:block, :with_block_hash)
          transaction = create(:ckb_transaction, block:,
                                                 contained_udt_ids: [udt.id], tags: ["udt"])
          transaction1 = create(:ckb_transaction, block:,
                                                  contained_udt_ids: [udt.id], tags: ["udt"])
          cell_output = create(:cell_output, block:,
                                             ckb_transaction: transaction,
                                             consumed_by: transaction1,
                                             status: "dead",
                                             type_hash: udt.type_hash,
                                             cell_type: "udt",
                                             data: "0x000050ad321ea12e0000000000000000")
          full_udt_address_ids << { address_id: cell_output.address.id,
                                    ckb_transaction_id: transaction.id }
        end
        udt.update(ckb_transactions_count: 40)
        AddressUdtTransaction.upsert_all full_udt_address_ids,
                                         unique_by: %i[address_id
                                                       ckb_transaction_id]
      end
    end

    trait :omiga_inscription do
      udt_type { "omiga_inscription" }
      published { true }
      after(:create) do |udt, _evaluator|
        create(:omiga_inscription_info,
               code_hash: "0x50fdea2d0030a8d0b3d69f883b471cab2a29cae6f01923f19cecac0f27fdaaa6",
               hash_type: "type",
               args: "0xcd89d8f36593a9a82501c024c5cdc4877ca11c5b3d5831b3e78334aecb978f0d",
               type_hash: "0x5cfcab1fc499de7d33265b04d2de9cf2f91cc7c7a578642993b0912b31b6cf39",
               decimal: udt.decimal,
               name: udt.full_name,
               symbol: udt.symbol,
               udt_hash: udt.type_hash,
               expected_supply: 0.21e16,
               mint_limit: 0.1e12,
               mint_status: "minting",
               udt_id: udt.id)
      end
    end

    trait :xudt do
      udt_type { "xudt" }
      published { true }
      full_name { "UniqueBBQ" }
      symbol { "BBQ" }
      decimal { 8 }
    end
  end
end
