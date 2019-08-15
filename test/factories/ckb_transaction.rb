FactoryBot.define do
  factory :ckb_transaction do
    block
    tx_hash { "0x#{SecureRandom.hex(32)}" }
    deps {}
    block_number {}
    block_timestamp { Faker::Time.between(2.days.ago, Date.today, :all).to_i }
    transaction_fee { 0 }
    version { 0 }
    witnesses {}

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

        create(:lock_script, cell_output_id: output1.id)
        create(:lock_script, cell_output_id: output2.id)
        create(:lock_script, cell_output_id: output3.id)
      end
    end

    trait :with_cell_output_and_lock_and_type_script do
      after(:create) do |ckb_transaction, _evaluator|
        output1 = create(:cell_output, capacity: 10**8 * 8, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: 0, generated_by: ckb_transaction)
        output2 = create(:cell_output, capacity: 10**8 * 8, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: 1, generated_by: ckb_transaction)
        output3 = create(:cell_output, capacity: 10**8 * 8, ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: 2, generated_by: ckb_transaction)
        create(:lock_script, cell_output_id: output1.id)
        create(:type_script, cell_output: output1)
        create(:lock_script, cell_output_id: output2.id)
        create(:type_script, cell_output: output2)
        create(:lock_script, cell_output_id: output3.id)
        create(:type_script, cell_output: output3)
      end
    end

    trait :with_multiple_inputs_and_outputs do
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
