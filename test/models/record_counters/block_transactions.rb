require "test_helper"

class BlockTransactionsTest < ActiveSupport::TestCase
  test "should respond to total_count" do
    block = create(:block, :with_block_hash)
    block_transactions_counter = RecordCounters::BlockTransactions.new(block)
    assert_respond_to block_transactions_counter, :total_count
  end

  test "total_count should return dao_contract ckb transactions count" do
    block = create(:block, :with_block_hash)
    block_transactions_counter = RecordCounters::BlockTransactions.new(block)
    assert_equal block.ckb_transactions_count, block_transactions_counter.total_count
  end
end
