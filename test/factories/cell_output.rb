FactoryBot.define do
  factory :cell_output do
    # block
    address
    status { "live" }
    capacity { 10**8 * 8 }
    data {}
    cell_type { "normal" }
    lock_script

    trait :with_full_transaction do
      before(:create) do |cell_output, _evaluator|
        ckb_transaction = create(:ckb_transaction, :with_cell_output_and_lock_script, block: cell_output.block)
        cell_output.update(ckb_transaction: ckb_transaction)
        lock = create(:lock_script, cell_output_id: cell_output.id, hash_type: "type")
        type = create(:type_script, cell_output_id: cell_output.id, hash_type: "type")
        cell_output.update(tx_hash: ckb_transaction.tx_hash, lock_script_id: lock.id, type_script_id: type.id)
      end
    end

    trait :with_full_transaction_but_no_type_script do
      before(:create) do |cell_output, _evaluator|
        block = create(:block, :with_block_hash)
        ckb_transaction = create(:ckb_transaction, :with_cell_output_and_lock_script)
        cell_output.update(ckb_transaction: ckb_transaction, block: block)
        lock = create(:lock_script, cell_output_id: cell_output.id)
        cell_output.update(lock_script_id: lock.id)
      end
    end

    after(:create) do |cell, _evaluator|
      if cell.live?
        cell.address.increment! :balance, cell.capacity
        cell.address.increment! :balance_occupied, cell.capacity if cell.occupied?
        cell.address.increment! :live_cells_count
      end
      AccountBook.upsert({ ckb_transaction_id: cell.ckb_transaction_id, address_id: cell.address_id },
                         unique_by: [:address_id, :ckb_transaction_id])
    end
  end
end
