require "test_helper"

class UdtTransactionsTest < ActiveSupport::TestCase
  test "should respond to total_count" do
    udt = create(:udt, published: true)
    udt_transactions_counter = RecordCounters::UdtTransactions.new(udt)
    assert_respond_to udt_transactions_counter, :total_count
  end

  test "total_count should return udt ckb transactions count" do
    udt = create(:udt, published: true)
    udt_transactions_counter = RecordCounters::UdtTransactions.new(udt)
    assert_equal udt.ckb_transactions_count, udt_transactions_counter.total_count
  end
end
