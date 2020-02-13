FactoryBot.define do
  factory :address do
    address_hash do
      script = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], args: "0x#{SecureRandom.hex(20)}", hash_type: "type")
      CKB::Address.new(script).generate
    end

    balance { 0 }
    cell_consumed { 0 }
    ckb_transactions_count { 0 }
    lock_hash { "0x#{SecureRandom.hex(32)}" }

    transient do
      transactions_count { 3 }
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
        ckb_transactions = create_list(:ckb_transaction, evaluator.transactions_count, block: block)
        address.ckb_transactions << ckb_transactions
      end
    end
  end
end
