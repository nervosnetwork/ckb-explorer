FactoryBot.define do
  factory :address do
    address_hash do
      script = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, args: "0x#{SecureRandom.hex(20)}",
                                      hash_type: "type")
      CKB::Address.new(script).generate
    end

    balance { 0 }
    ckb_transactions_count { 0 }
    lock_hash { "0x#{SecureRandom.hex(32)}" }
    last_updated_block_number { 10 }

    transient do
      transactions_count { 3 }
    end

    transient do
      udt { create(:udt, published: true) }
    end

    before(:create) do |address|
      parsed_address = CkbUtils.parse_address(address.address_hash)
      lock = LockScript.find_or_create_by(args: parsed_address.script.args, code_hash: parsed_address.script.code_hash, hash_type: parsed_address.script.hash_type,
                                          script_hash: parsed_address.script.compute_hash)
      address.update(lock_hash: lock.script_hash, lock_script_id: lock.id)
    end

    trait :with_transactions do
      ckb_transactions_count { 3 }
      after(:create) do |address, evaluator|
        block = create(:block, :with_block_hash)
        ckb_transactions = []
        evaluator.transactions_count.times do |i|
          ckb_transactions << create(:ckb_transaction, block:, block_timestamp: Time.current.to_i + i, tx_index: i)
        end

        AccountBook.upsert_all(ckb_transactions.map { |t| { address_id: address.id, ckb_transaction_id: t.id, block_number: t.block_number, tx_index: t.tx_index } })
        address.update(ckb_transactions_count: address.ckb_transactions.count)
      end
    end

    trait :with_pending_transactions do
      ckb_transactions_count { 3 }
      after(:create) do |address, evaluator|
        block = create(:block, :with_block_hash)
        ckb_transactions = []
        evaluator.transactions_count.times do |i|
          ckb_transactions << create(:pending_transaction, :with_multiple_inputs_and_outputs, block:,
                                                                                              block_timestamp: Time.current.to_i + i)
        end

        attrs =
          ckb_transactions.map do |t|
            income = t.outputs.where(address:).sum(:capacity) - t.input_cells.where(address:).sum(:capacity)
            { address_id: address.id, ckb_transaction_id: t.id, income: }
          end
        AccountBook.upsert_all(attrs)
        address.update(ckb_transactions_count: address.ckb_transactions.count)
      end
    end

    trait :with_udt_transactions do
      ckb_transactions_count { 20 }
      after(:create) do |address, evaluator|
        evaluator.transactions_count.times do
          block = create(:block, :with_block_hash)
          transaction = create(:ckb_transaction, block:, udt_address_ids: [address.id], tags: ["udt"])
          transaction.contained_address_ids = [address.id]
          transaction.contained_udt_ids = [evaluator.udt.id]
          transaction1 = create(:ckb_transaction, block:, udt_address_ids: [address.id], tags: ["udt"])
          transaction1.contained_address_ids = [address.id]
          transaction1.contained_udt_ids = [evaluator.udt.id]
          create(:cell_output, address:,
                               block:,
                               ckb_transaction: transaction,
                               consumed_by: transaction1,
                               status: "dead",
                               type_hash: evaluator.udt.type_hash,
                               cell_type: "udt",
                               data: "0x000050ad321ea12e0000000000000000")
        end
      end
    end
  end
end
