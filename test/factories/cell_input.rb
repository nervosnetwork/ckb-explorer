FactoryBot.define do
  factory :cell_input do
    trait :from_cellbase do
      before(:create) do |cell_input, _evaluator|
        ckb_transaction = create(:ckb_transaction, :with_cell_output_and_lock_script)
        # previous_output = nil  # { tx_hash: CellOutput::SYSTEM_TX_HASH, index: "4294967295" }
        cell_input.update(ckb_transaction: ckb_transaction, previous_cell_output_id: nil, block: ckb_transaction.block)
      end
    end

    trait :with_full_transaction do
      before(:create) do |cell_input, _evaluator|
        ckb_transaction = create(:ckb_transaction, :with_cell_output_and_lock_script)
        previous_output_id = ckb_transaction.cell_outputs.where(cell_index: 0).pick(:id)
        cell_input.update(
          ckb_transaction: ckb_transaction,
          previous_cell_output_id: previous_output_id,
          block: ckb_transaction.block
        )
      end
    end

    trait :with_full_transaction_and_type_script do
      before(:create) do |cell_input, _evaluator|
        ckb_transaction = create(:ckb_transaction, :with_cell_output_and_lock_and_type_script)
        previous_output_id = ckb_transaction.cell_outputs.where(cell_index: 0).pick(:id)
        cell_input.update(
          ckb_transaction: ckb_transaction,
          previous_cell_output_id: previous_output_id,
          block: ckb_transaction.block
        )
      end
    end
    after(:create) do |cell_input, _evaluator|
      if cell_input.previous_cell_output_id.blank? && cell_input.previous_output.present? && cell_input.previous_output["tx_hash"] != CellOutput::SYSTEM_TX_HASH
        output = CellOutput.find_by(tx_hash: cell_input.previous_output["tx_hash"],
                                    cell_index: cell_input.previous_output["index"])
        unless output
          tx = create :ckb_transaction, :with_single_output, tx_hash: cell_input.previous_output["tx_hash"]
          output = tx.cell_outputs.first
        end
        cell_input.update(previous_cell_output_id: output.id)
      end
    end
  end
end
