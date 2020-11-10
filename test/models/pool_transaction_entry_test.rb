require "test_helper"

class PoolTransactionEntryTest < ActiveSupport::TestCase
  test "is_cellbase should always be false" do
    tx = create(:pool_transaction_entry)
    assert_equal false, tx.is_cellbase
  end

  test "income should always be nil" do
    tx = create(:pool_transaction_entry)
    assert_nil tx.income
  end
end
