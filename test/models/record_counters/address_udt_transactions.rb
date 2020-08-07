require "test_helper"

class AddressUdtTransactionsTest < ActiveSupport::TestCase
  test "should respond to total_count" do
    address = create(:address)
    udt = create(:udt, published: true)
    address_udt_transactions_counter = RecordCounters::AddressUdtTransactions.new(address, udt.id)
    assert_respond_to address_udt_transactions_counter, :total_count
  end

  test "total_count should return address udt transactions count" do
    address = create(:address)
    udt = create(:udt, published: true)
    address_udt_transactions_counter = RecordCounters::AddressUdtTransactions.new(address, udt.id)
    assert_equal address.ckb_udt_transactions(udt.id).count, address_udt_transactions_counter.total_count
  end
end
