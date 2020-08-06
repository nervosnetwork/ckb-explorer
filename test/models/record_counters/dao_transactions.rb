require "test_helper"

class DaoTransactionsTest < ActiveSupport::TestCase
  test "should respond to total_count" do
    dao_contract = DaoContract.default_contract
    dao_transactions_counter = RecordCounters::DaoTransactions.new(dao_contract)
    assert_respond_to dao_transactions_counter, :total_count
  end

  test "total_count should return dao_contract ckb transactions count" do
    dao_contract = DaoContract.default_contract
    dao_transactions_counter = RecordCounters::DaoTransactions.new(dao_contract)
    assert_equal dao_contract.ckb_transactions_count, dao_transactions_counter.total_count
  end
end