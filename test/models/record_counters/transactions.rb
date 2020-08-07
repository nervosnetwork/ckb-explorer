require "test_helper"

class TransactionsTest < ActiveSupport::TestCase
  test "should respond to total_count" do
    transactions_counter = RecordCounters::Transactions.new
    assert_respond_to transactions_counter, :total_count
  end

  test "total_count should return block ckb transactions count" do
    create(:ckb_transaction)
    create(:table_record_count, :ckb_transactions_counter, count: CkbTransaction.count)
    transactions_counter = RecordCounters::Transactions.new
    assert_equal CkbTransaction.count, transactions_counter.total_count
  end
end
