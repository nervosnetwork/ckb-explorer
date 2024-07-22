require "test_helper"

class TokenCollectionTagWorkerTest < ActiveJob::TestCase
  setup do
    @address = create(:address, address_hash: "ckb1qz7xc452rgxs5z0ks3xun46dmdp58sepg0ljtae8ck0d7nah945nvqgqqqqqqx3l3v4")
    tx = create(:ckb_transaction)
    @cell = create(:cell_output, address_id: @address.id, ckb_transaction_id: tx.id, tx_hash: tx.tx_hash)
  end

  test "add invalid tag to token_collection" do
    create(:token_collection, name: "ü", cell_id: @cell.id, creator_id: @address.id)
    TokenCollectionTagWorker.new.perform
    assert_equal ["invalid"], TokenCollection.last.tags
  end

  test "add suspicious tag to token_collection" do
    create(:token_collection, name: "CK  BB", cell_id: @cell.id, creator_id: @address.id)
    TokenCollectionTagWorker.new.perform
    assert_equal ["suspicious"], TokenCollection.last.tags
  end

  test "add out-of-length-range tag to token_collection" do
    create(:token_collection, name: "C" * 256, cell_id: @cell.id, creator_id: @address.id)
    TokenCollectionTagWorker.new.perform
    assert_equal ["out-of-length-range"], TokenCollection.last.tags
  end

  test "add rgb++ tag to token_collection" do
    create(:token_collection, name: "CKBNFT", cell_id: @cell.id, creator_id: @address.id, block_timestamp: 1.hour.ago.to_i)
    TokenCollectionTagWorker.new.perform
    assert_equal ["rgb++", "layer-1-asset"], TokenCollection.last.tags
  end
end
