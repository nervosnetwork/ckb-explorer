FactoryBot.define do
  factory :ckb_transaction do
    block
    tx_hash { "0x#{SecureRandom.hex(32)}" }
    tx_status { "committed" }
    block_number { block.number }
    block_timestamp { block.timestamp }
    transaction_fee { 100 }
    version { 0 }
    bytes { 2000 }

    transient do
      address { nil }
      udt_address_ids { [] }
      witnesses { [] }
      header_deps { [] }
      cell_deps { [] }
    end

    after(:create) do |tx, eval|
      tx.contained_udt_address_ids = eval.udt_address_ids if eval.udt_address_ids.present?
      if eval.witnesses.present?
        i = -1
        eval.witnesses.each do |witness|
          i += 1
          create(:witness, ckb_transaction: tx, data: witness, index: i)
        end
      end
      if eval.header_deps.present?
        i = -1
        eval.header_deps.each do |header_dep|
          i += 1
          create(:header_dependency, ckb_transaction: tx,
                                     header_hash: header_dep, index: i)
        end
      end
      if eval.cell_deps.present?
        DeployedCell.create_initial_data_for_ckb_transaction tx, eval.cell_deps
      end
    end

    transient do
      code_hash { nil }
    end

    transient do
      args { nil }
    end

    factory :pending_transaction do
      tx_hash { "0x#{SecureRandom.hex(32)}" }
      tx_status { "pending" }
      block_number { nil }
      block_timestamp { nil }
      transaction_fee { 100 }
      version { 0 }
      bytes { 2000 }
    end

    trait :with_cell_output_and_lock_script do
      after(:create) do |ckb_transaction, _evaluator|
        output1 = create(:cell_output, ckb_transaction: ckb_transaction,
                                       block: ckb_transaction.block,
                                       tx_hash: ckb_transaction.tx_hash,
                                       cell_index: 0)
        output2 = create(:cell_output, ckb_transaction: ckb_transaction,
                                       block: ckb_transaction.block,
                                       tx_hash: ckb_transaction.tx_hash,
                                       cell_index: 1)
        output3 = create(:cell_output, ckb_transaction: ckb_transaction,
                                       block: ckb_transaction.block,
                                       tx_hash: ckb_transaction.tx_hash,
                                       cell_index: 2)

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
        output1 = create(:cell_output, capacity: 10**8 * 8,
                                       ckb_transaction: ckb_transaction,
                                       block: ckb_transaction.block,
                                       tx_hash: ckb_transaction.tx_hash,
                                       cell_index: 0)
        output2 = create(:cell_output, capacity: 10**8 * 8,
                                       ckb_transaction: ckb_transaction,
                                       block: ckb_transaction.block,
                                       tx_hash: ckb_transaction.tx_hash,
                                       cell_index: 1)
        output3 = create(:cell_output, capacity: 10**8 * 8,
                                       ckb_transaction: ckb_transaction,
                                       block: ckb_transaction.block,
                                       tx_hash: ckb_transaction.tx_hash,
                                       cell_index: 2)
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
          tx = create(:ckb_transaction, :with_cell_output_and_lock_script,
                      block: block)
          create(:cell_output, capacity: 10**8 * 8,
                               ckb_transaction: ckb_transaction, block: ckb_transaction.block, tx_hash: ckb_transaction.tx_hash, cell_index: index)
          previous_output = { tx_hash: tx.tx_hash, index: 0 }
          create(:cell_input, previous_output: previous_output,
                              ckb_transaction: ckb_transaction, block: ckb_transaction.block)

          ckb_transaction.witnesses.create index: index,
                                           data: "0x4e52933358ae2f26863b8c1c71bf20f17489328820f8f2cd84a070069f10ceef784bc3693c3c51b93475a7b5dbf652ba6532d0580ecc1faf909f9fd53c5f6405000000000000000000"
        end
      end
    end

    trait :with_single_output do
      after(:create) do |ckb_transaction|
        create(:cell_output, capacity: 10**8 * 8,
                             ckb_transaction: ckb_transaction,
                             block: ckb_transaction.block,
                             tx_hash: ckb_transaction.tx_hash,
                             cell_index: 0)
      end
    end

    trait :cell_base_with_multiple_inputs_and_outputs do
      after(:create) do |ckb_transaction|
        15.times do |index|
          create(:cell_output, capacity: 10**8 * 8,
                               ckb_transaction: ckb_transaction,
                               block: ckb_transaction.block,
                               tx_hash: ckb_transaction.tx_hash,
                               cell_index: index)
          previous_output = { tx_hash: ckb_transaction.tx_hash, index: 1 }
          create(:cell_input, previous_output: previous_output,
                              ckb_transaction: ckb_transaction,
                              block: ckb_transaction.block)
        end
      end
    end
    factory :cell_base_transaction do
    end
  end
end
