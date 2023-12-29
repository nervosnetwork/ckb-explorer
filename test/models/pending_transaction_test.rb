require "test_helper"

class PendingTransactionTest < ActiveSupport::TestCase
  setup do
    CkbSync::Api.any_instance.stubs(:generate_json_rpc_id).returns(1)
  end

  test "is_cellbase should always be false" do
    tx = create(:pending_transaction)
    assert_equal false, tx.is_cellbase
  end

  test "#to_raw should return raw tx json structure" do
    tx = create(:pending_transaction)
    json = tx.to_raw
    assert_equal %w(hash header_deps cell_deps inputs outputs outputs_data version witnesses).sort,
                 json.keys.map(&:to_s).sort
  end
end
