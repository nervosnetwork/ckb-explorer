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
  test "#to_raw should return raw tx json structure" do
    tx = create(:pool_transaction_entry)
    json = tx.to_raw
    assert_equal %w(hash header_deps inputs outputs outputs_data version witnesses).sort, tx.keys.sort
  end

end
