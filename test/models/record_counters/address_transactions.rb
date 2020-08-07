require "test_helper"

class AddressTransactionsTest < ActiveSupport::TestCase
  test "should respond to total_count" do
    address = create(:address)
    address_transactions_counter = RecordCounters::AddressTransactions.new(address)
    assert_respond_to address_transactions_counter, :total_count
  end

  test "total_count should return address ckb transactions count" do
    address = create(:address)
    address_transactions_counter = RecordCounters::AddressTransactions.new(address)
    assert_equal address.ckb_transactions_count, address_transactions_counter.total_count
  end
end
