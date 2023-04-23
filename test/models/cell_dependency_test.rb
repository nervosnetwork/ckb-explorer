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
end
