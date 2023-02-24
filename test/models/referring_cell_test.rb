require "test_helper"

class ReferringCellTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:ckb_transaction)
    should belong_to(:contract)
    should belong_to(:cell_output)
  end

  setup do
    @block = create(:block, :with_block_hash)
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block_id: @block.id)
    @cell_output = create(:cell_output, :with_full_transaction, ckb_transaction_id: @ckb_transaction.id, block: @block)
    @contract = create :contract
    @referring_cell = create :referring_cell, ckb_transaction_id: @ckb_transaction.id, cell_output_id: @cell_output.id, contract_id: @contract.id
  end

  test "it should create referring_cell" do
    assert_equal @cell_output.id, @referring_cell.cell_output_id
    assert_equal @contract.id, @referring_cell.contract_id
    assert_equal @ckb_transaction.id, @referring_cell.ckb_transaction_id
  end

  test "it should belongs_to ckb_transaction, cell_output and contract" do
    assert_equal @cell_output, @referring_cell.cell_output
    assert_equal @contract, @referring_cell.contract
    assert_equal @ckb_transaction, @referring_cell.ckb_transaction
  end

end
