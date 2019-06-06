FactoryBot.define do
  factory :cell_output do
    address

    capacity { 10**8 * 5 }
    data {}

    trait :with_full_transaction do
      before(:create) do |cell_output, _evaluator|
        ckb_transaction = create(:ckb_transaction, :with_cell_output_and_lock_script, block: cell_output.block)
        cell_output.update(ckb_transaction: ckb_transaction)
        create(:lock_script, cell_output: cell_output)
        create(:type_script, cell_output: cell_output)
      end
    end

    trait :with_full_transaction_but_no_type_script do
      before(:create) do |cell_output, _evaluator|
        block = create(:block, :with_block_hash)
        ckb_transaction = create(:ckb_transaction, :with_cell_output_and_lock_script)
        cell_output.update(ckb_transaction: ckb_transaction, block: block)
        create(:lock_script, cell_output: cell_output)
      end
    end
  end
end
