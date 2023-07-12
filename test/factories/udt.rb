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
          transaction = create(:ckb_transaction, block: block, contained_udt_ids: [udt.id], tags: ["udt"])
          transaction1 = create(:ckb_transaction, block: block, contained_udt_ids: [udt.id], tags: ["udt"])
          cell_output = create(:cell_output, block: block,
                                             ckb_transaction: transaction,
                                             consumed_by: transaction1,
                                             status: "dead",
                                             type_hash: udt.type_hash,
                                             cell_type: "udt",
                                             data: "0x000050ad321ea12e0000000000000000")
          full_udt_address_ids << { address_id: cell_output.address.id, ckb_transaction_id: transaction.id }
        end
        udt.update(ckb_transactions_count: 40)
        AddressUdtTransaction.upsert_all full_udt_address_ids,
                                         unique_by: [:address_id, :ckb_transaction_id]
      end
    end
  end
end
