require "test_helper"

module Api
  module V2
    class NFT::CollectionsControllerTest < ActionDispatch::IntegrationTest
      test "should get index" do
        create :token_collection, name: "token1"
        create :token_collection, name: "token2"

        get api_v2_nft_collections_url
        assert_response :success
        assert_equal JSON.parse(response.body)["data"].size, 2
      end

      test "sort by block_timestamp asc" do
        block1 = create(:block, :with_block_hash, timestamp: 10.days.ago.to_i * 1000)
        block3 = create(:block, :with_block_hash, timestamp: 1.day.ago.to_i * 1000)
        transaction1 = create(:ckb_transaction, block: block1)
        transaction3 = create(:ckb_transaction, block: block3)
        cell1 = create(:cell_output, block_timestamp: 10.days.ago.to_i * 1000, block: block1, ckb_transaction: transaction1)
        cell3 = create(:cell_output, block_timestamp: 1.day.ago.to_i * 1000, block: block3, ckb_transaction: transaction3)
        tc1 = create :token_collection, name: "token1", cell_id: cell1.id
        tc2 = create :token_collection, name: "token2"
        _tc3 = create :token_collection, name: "token3", cell_id: cell3.id
        get api_v2_nft_collections_url, params: { sort: "timestamp.asc" }
        assert_response :success
        assert_equal tc1.id, json["data"].first["id"]
        assert_equal tc2.id, json["data"].last["id"]
      end

      test "sort by block_timestamp desc" do
        timestamp = 10.days.ago.to_i * 1000
        block1 = create(:block, :with_block_hash, timestamp:)
        block3 = create(:block, :with_block_hash, timestamp: 1.day.ago.to_i * 1000)
        transaction1 = create(:ckb_transaction, block: block1)
        transaction3 = create(:ckb_transaction, block: block3)
        cell1 = create(:cell_output, block_timestamp: timestamp, block: block1, ckb_transaction: transaction1)
        cell3 = create(:cell_output, block_timestamp: 1.day.ago.to_i * 1000, block: block3, ckb_transaction: transaction3)
        tc1 = create :token_collection, name: "token1", cell_id: cell1.id
        tc2 = create :token_collection, name: "token2"
        _tc3 = create :token_collection, name: "token3", cell_id: cell3.id

        get api_v2_nft_collections_url, params: { sort: "timestamp.desc" }
        assert_response :success
        assert_equal tc2.id, json["data"].first["id"]
        assert_equal tc1.id, json["data"].last["id"]
        assert_equal timestamp, json["data"].last["timestamp"]
      end

      test "should get show" do
        sn = "001-sn"
        name = "token-with-sn"
        create(:token_collection, name:, sn:)

        get api_v2_nft_collection_url(id: sn)

        assert_response :success
        assert_equal JSON.parse(response.body)["name"], name
      end
    end
  end
end
