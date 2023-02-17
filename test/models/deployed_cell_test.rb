require "test_helper"

class DeployedCellTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:contract)
    should belong_to(:cell_output)
  end

  setup do
    @block = create(:block, :with_block_hash)
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block_id: @block.id)
    @cell_output = create(:cell_output, :with_full_transaction, ckb_transaction_id: @ckb_transaction.id, block: @block)
    @contract = create :contract
    @deployed_cell = create :deployed_cell, contract_id: @contract.id, cell_output_id: @cell_output.id
  end

  test "it should create deployed_cell" do
    assert_equal @cell_output.id, @deployed_cell.cell_output_id
    assert_equal @contract.id, @deployed_cell.contract_id
  end

  test "it should belongs_to contract and cell_output" do
    assert_equal @cell_output, @deployed_cell.cell_output
    assert_equal @contract, @deployed_cell.contract
  end

end
