require "test_helper"

class AddressDaoTransactionsTest < ActiveSupport::TestCase
  test "should respond to total_count" do
    address = create(:address)
    address_dao_transactions_counter = RecordCounters::AddressDaoTransactions.new(address)
    assert_respond_to address_dao_transactions_counter, :total_count
  end

  test "total_count should return dao_contract ckb transactions count" do
    address = create(:address)
    address_dao_transactions_counter = RecordCounters::AddressDaoTransactions.new(address)
    assert_equal address.dao_transactions_count, address_dao_transactions_counter.total_count
  end
end
