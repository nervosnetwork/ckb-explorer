require "test_helper"

class CellDependencyTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:script)
    should belong_to(:cell_output)
    should belong_to(:ckb_transaction)
  end

  setup do
    @contract = create :contract
    @block = create(:block, :with_block_hash)
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block)
    @cell_output = create :cell_output, :with_full_transaction, block: @block
    @script = create :script
    @cell_dependency = create :cell_dependency, contract_id: @contract.id, ckb_transaction_id: @ckb_transaction.id, contract_cell_id: @cell_output.id,
      script_id: @script.id
  end

  test "it should create contract" do
    assert_equal @contract.id, @cell_dependency.contract_id
    assert_equal "dep_group", @cell_dependency.dep_type
    assert_equal @cell_output.id, @cell_dependency.contract_cell_id
    assert_equal @ckb_transaction.id, @cell_dependency.ckb_transaction_id
  end

  test "it should update contract" do
    @cell_dependency.update dep_type: :dep_group
    assert_equal "dep_group", @cell_dependency.dep_type
  end

  test "it should belongs_to contract" do
    assert_equal @contract, @cell_dependency.contract
  end

  test "it should create_from_scripts" do
    CkbTransaction.delete_all
    CellOutput.delete_all
    LockScript.delete_all
    TypeScript.delete_all
    Contract.delete_all
    puts CellDependency.count
    CellDependency.delete_all
    Script.delete_all

    contract = create :contract
    script = create :script, contract_id: contract.id
    block = create(:block, :with_block_hash)
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block)
    cell_output = create :cell_output, :with_full_transaction, block: block
    lock_script = create :lock_script, script_id: script.id
    type_script = create :type_script, script_id: script.id
    cell_output.update lock_script_id: lock_script.id, type_script_id: type_script.id
    LockScript.where('script_id is null').delete_all
    TypeScript.where('script_id is null').delete_all

    # for the 1st time, it will create
    CellDependency.create_from_scripts TypeScript.all
    CellDependency.create_from_scripts LockScript.all
    cell_dependency = CellDependency.where('script_id = ?', script.id).first
    cell_output_ids_of_lock_script_or_type_script = lock_script.ckb_transactions.first.cell_outputs.map {|e| e.id}
    cell_output_ids_of_cell_dependency = CellDependency.all.map {|e| e.contract_cell_id}
    Rails.logger.info "=== CellDependency.count #{CellDependency.count}"
    assert_equal 4, CellDependency.count
    assert_equal contract.id, cell_dependency.contract_id
    assert_equal lock_script.ckb_transactions.first.id, cell_dependency.ckb_transaction_id
    assert_equal cell_output_ids_of_lock_script_or_type_script.sort, cell_output_ids_of_cell_dependency.sort

    # for the 2nd time, it should NOT create new record
    CellDependency.create_from_scripts TypeScript.all
    CellDependency.create_from_scripts LockScript.all
    Rails.logger.info "=== 2nd CellDependency.count #{CellDependency.count}"
    assert_equal 4, CellDependency.count
  end
end
