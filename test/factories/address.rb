FactoryBot.define do
  factory :address do
    address_hash do
      script = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], args: "0x#{SecureRandom.hex(20)}", hash_type: "type")
      CKB::Address.new(script).generate
    end

    address_hash_crc { CkbUtils.generate_crc32(address_hash) }

    balance { 0 }
    cell_consumed { 0 }
    ckb_transactions_count { 0 }
    lock_hash { "0x#{SecureRandom.hex(32)}" }

    transient do
      transactions_count { 3 }
    end

    transient do
      udt { create(:udt, published: true) }
    end

    after(:create) do |address|
      lock_hash = CkbUtils.parse_address(address.address_hash).script.compute_hash
      address.update(lock_hash: lock_hash)
    end

    trait :with_lock_script do
      after(:create) do |address, _evaluator|
        block = create(:block, :with_block_hash)
        cell_output = create(:cell_output, :with_full_transaction, block: block)
        cell_output.lock_script.update(address: address)
      end
    end

    trait :with_transactions do
      ckb_transactions_count { 3 }
      after(:create) do |address, evaluator|
        block = create(:block, :with_block_hash)
        ckb_transactions = []
        evaluator.transactions_count.times do |i|
          ckb_transactions << create(:ckb_transaction, block: block, block_timestamp: Time.current.to_i + i)
        end

        ckb_transactions.each do |tx|
          tx.contained_address_ids << address.id
        end
        address.ckb_transactions << ckb_transactions
        address.update(ckb_transactions_count: address.ckb_transactions.count)
      end
    end

    trait :with_udt_transactions do
      ckb_transactions_count { 20 }
      after(:create) do |address, evaluator|
        evaluator.transactions_count.times do
          block = create(:block, :with_block_hash)
          transaction = create(:ckb_transaction, block: block, udt_address_ids: [address.id], contained_address_ids: [address.id], tags: ["udt"], contained_udt_ids: [evaluator.udt.id])
          transaction1 = create(:ckb_transaction, block: block, udt_address_ids: [address.id], contained_address_ids: [address.id], tags: ["udt"], contained_udt_ids: [evaluator.udt.id])
          create(:cell_output, address: address, block: block, ckb_transaction: transaction, generated_by: transaction, consumed_by: transaction1, type_hash: evaluator.udt.type_hash, cell_type: "udt", data: "0x000050ad321ea12e0000000000000000")
          address.ckb_transactions << transaction
          address.ckb_transactions << transaction1
        end
      end
    end
  end
end
