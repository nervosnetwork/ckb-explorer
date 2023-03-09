FactoryBot.define do
  factory :ckb_transaction do
    block
    tx_hash { "0x#{SecureRandom.hex(32)}" }
    tx_status { "committed" }
    block_number {}
    block_timestamp { block.timestamp }
    transaction_fee { 0 }
    version { 0 }
    witnesses {}
    bytes { 2000 }

    transient do
      address { nil }
    end

    transient do
      code_hash { nil }
    end

    transient do
      args { nil }
    end

    trait :with_cell_output_and_lock_script do
      after(:create) do |ckb_transaction, _evaluator|
        output1 = create(:cell_output, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: 0, generated_by: ckb_transaction)
        output2 = create(:cell_output, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: 1, generated_by: ckb_transaction)
        output3 = create(:cell_output, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: 2, generated_by: ckb_transaction)

        lock1 = create(:lock_script, cell_output_id: output1.id)
        lock2 = create(:lock_script, cell_output_id: output2.id)
        lock3 = create(:lock_script, cell_output_id: output3.id)
        output1.update(lock_script_id: lock1.id)
        output2.update(lock_script_id: lock2.id)
        output3.update(lock_script_id: lock3.id)
      end
    end

    trait :with_cell_output_and_lock_and_type_script do
      after(:create) do |ckb_transaction, _evaluator|
        output1 = create(:cell_output, capacity: 10**8 * 8, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: 0, generated_by: ckb_transaction)
        output2 = create(:cell_output, capacity: 10**8 * 8, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: 1, generated_by: ckb_transaction)
        output3 = create(:cell_output, capacity: 10**8 * 8, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: 2, generated_by: ckb_transaction)
        lock1 = create(:lock_script, cell_output_id: output1.id)
        type1 = create(:type_script, cell_output: output1)
        lock2 = create(:lock_script, cell_output_id: output2.id)
        type2 = create(:type_script, cell_output: output2)
        lock3 = create(:lock_script, cell_output_id: output3.id)
        type3 = create(:type_script, cell_output: output3)
        output1.update(lock_script_id: lock1.id, type_script_id: type1.id)
        output2.update(lock_script_id: lock2.id, type_script_id: type2.id)
        output3.update(lock_script_id: lock3.id, type_script_id: type3.id)
      end
    end

    trait :with_multiple_inputs_and_outputs do
      after(:create) do |ckb_transaction|
        15.times do |index|
          block = create(:block, :with_block_hash, number: 12)
          tx = create(:ckb_transaction, :with_cell_output_and_lock_script, block: block)
          create(:cell_output, capacity: 10**8 * 8, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: index, generated_by: ckb_transaction)
          previous_output = { tx_hash: tx.tx_hash, index: 0 }
          create(:cell_input, previous_output: previous_output, ckb_transaction: ckb_transaction, block: ckb_transaction.block)
          ckb_transaction.update(witnesses: %w(0x0x4e52933358ae2f26863b8c1c71bf20f17489328820f8f2cd84a070069f10ceef784bc3693c3c51b93475a7b5dbf652ba6532d0580ecc1faf909f9fd53c5f6405000000000000000000))
        end
      end
    end

    trait :with_single_output do
      after(:create) do |ckb_transaction|
        create(:cell_output, capacity: 10**8 * 8, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: 0, generated_by: ckb_transaction)
      end
    end

    trait :cell_base_with_multiple_inputs_and_outputs do
      after(:create) do |ckb_transaction|
        15.times do |index|
          create(:cell_output, capacity: 10**8 * 8, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: index, generated_by: ckb_transaction)
          previous_output = { tx_hash: ckb_transaction.tx_hash, index: 1 }
          create(:cell_input, previous_output: previous_output, ckb_transaction: ckb_transaction, block: ckb_transaction.block)
        end
      end
    end
  end
end
