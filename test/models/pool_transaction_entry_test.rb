require "test_helper"

class PoolTransactionEntryTest < ActiveSupport::TestCase

  setup do
    CkbSync::Api.any_instance.stubs(:generate_json_rpc_id).returns(1)
  end

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
    assert_equal %w(hash header_deps cell_deps inputs outputs outputs_data version witnesses).sort, json.keys.map(&:to_s).sort
  end

  test "should update_detailed_message_for_rejected_transaction when detailed_message is nil" do

    rejected_tx_id = '0xed2049c21ffccfcd26281d60f8f77ff117adb9df9d3f8cbe5fe86e893c66d359'
    tx = create :pool_transaction_entry, tx_status: :rejected, tx_hash: rejected_tx_id


    VCR.use_cassette('get_rejected_transaction') do
      tx.update_detailed_message_for_rejected_transaction
    end

    assert tx.detailed_message.include?("Resolve failed Dead")
  end

end
