FactoryBot.define do
  factory :cell_output do
    block
    address
    status { "live" }
    capacity { (10**8) * 8 }
    transient do
      data { nil }
    end
    cell_type { "normal" }
    sequence :block_timestamp do |n|
      (Time.now.to_i + n) * 1000
    end
    lock_script

    trait :with_full_transaction do
      before(:create) do |cell_output, _evaluator|
        ckb_transaction = create(:ckb_transaction, :with_cell_output_and_lock_script, block: cell_output.block)
        cell_output.update(ckb_transaction:)
        lock = create(:lock_script, hash_type: "type")
        type = create(:type_script, hash_type: "type")
        cell_output.update(tx_hash: ckb_transaction.tx_hash, lock_script_id: lock.id, type_script_id: type.id)
      end
    end

    trait :address_live_cells do
      before(:create) do |cell_output, _evaluator|
        block = create(:block, :with_block_hash)
        ckb_transaction = create(:ckb_transaction, :with_cell_output_and_lock_script)
        cell_output.update(ckb_transaction:, block:)
      end
    end

    trait :with_full_transaction_but_no_type_script do
      before(:create) do |cell_output, _evaluator|
        block = create(:block, :with_block_hash)
        ckb_transaction = create(:ckb_transaction, :with_cell_output_and_lock_script)
        cell_output.update(ckb_transaction:, block:)
        lock = create(:lock_script)
        cell_output.update(lock_script_id: lock.id)
      end
    end

    after(:create) do |cell, _evaluator|
      if _evaluator.data
        cell.data = _evaluator.data
      end
      if cell.live?
        cell.address.increment! :balance, cell.capacity
        cell.address.increment! :balance_occupied, cell.capacity if cell.occupied?
        cell.address.increment! :live_cells_count
      end
      income = cell.ckb_transaction.outputs.where(address: cell.address).sum(:capacity) - cell.ckb_transaction.inputs.where(address: cell.address).sum(:capacity)
      AccountBook.upsert({ ckb_transaction_id: cell.ckb_transaction_id, address_id: cell.address_id, block_number: cell.block&.number, tx_index: cell.ckb_transaction.tx_index, income: },
                         unique_by: %i[address_id ckb_transaction_id])
    end
  end
end
