require "test_helper"

class CellDependencyTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:cell_output)
    should belong_to(:ckb_transaction)
  end

  setup do
    @block = create(:block, :with_block_hash)
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block)
    @cell_output = create :cell_output, :with_full_transaction, block: @block
    @contract = create :contract, deployed_cell_output_id: @cell_output.id
    @cell_dependency = create :cell_dependency, ckb_transaction_id: @ckb_transaction.id, contract_cell_id: @cell_output.id
    create :cell_deps_out_point, contract_cell_id: @cell_output.id, deployed_cell_output_id: @cell_output.id
  end

  test "it should create contract" do
    assert_equal "code", @cell_dependency.dep_type
    assert_equal @cell_output.id, @cell_dependency.contract_cell_id
    assert_equal @ckb_transaction.id, @cell_dependency.ckb_transaction_id
  end
end
