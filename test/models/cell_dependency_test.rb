require "test_helper"

class CellDependencyTest < ActiveSupport::TestCase
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
    assert_equal 1, @cell_dependency.dep_type
    assert_equal @cell_output.id, @cell_dependency.contract_cell_id
    assert_equal @ckb_transaction.id, @cell_dependency.ckb_transaction_id
  end

  test "it should update contract" do
    @cell_dependency.update dep_type: 2
    assert_equal 2, @cell_dependency.dep_type
  end

  test "it should belongs_to contract, ckb_transaction and cell_output" do
    assert_equal @contract, @cell_dependency.contract
    assert_equal @cell_output, @cell_dependency.cell_output
    assert_equal @ckb_transaction, @cell_dependency.ckb_transaction
  end

  test "it should belongs_to script" do
    assert_equal @script, @cell_dependency.script
  end
end
