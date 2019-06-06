FactoryBot.define do
  factory :address do
    address_hash { CKB::Address.new("0x#{SecureRandom.hex(32)}").generate }
    balance { 0 }
    cell_consumed { 0 }
    ckb_transactions_count { 0 }
    lock_hash { "0x#{SecureRandom.hex(32)}" }

    transient do
      transactions_count { 3 }
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
