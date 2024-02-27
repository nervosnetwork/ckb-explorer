require "test_helper"

module Api
  module V2
    class NFT::ItemsControllerTest < ActionDispatch::IntegrationTest
      def setup
        super
      end

      test "should get index with collection id" do
        token_collection = create :token_collection, name: "token1"
        address = create :address, is_depositor: true

        create :token_item, name: "item1", collection_id: token_collection.id, owner_id: address.id
        create :token_item, name: "item2", collection_id: token_collection.id, owner_id: address.id

        get api_v2_nft_collection_items_url(collection_id: token_collection.id)
        assert_response :success
        assert_equal JSON.parse(response.body)["data"].size, 2
      end

      test "should get index with collection sn" do
        sn = "iam-an-sn"
        token_collection = create(:token_collection, name: "token1", sn:)
        address = create :address, is_depositor: true

        create :token_item, name: "item1", collection_id: token_collection.id, owner_id: address.id
        create :token_item, name: "item2", collection_id: token_collection.id, owner_id: address.id

        get api_v2_nft_collection_items_url(collection_id: sn)
        assert_response :success
        assert_equal JSON.parse(response.body)["data"].size, 2
      end

      test "should get show" do
        token_collection = create :token_collection, name: "token1"
        address = create :address, is_depositor: true

        my_token_id = 100
        token_item = create :token_item, name: "item1", collection_id: token_collection.id, owner_id: address.id,
                                         token_id: my_token_id

        get api_v2_nft_collection_item_url(id: my_token_id, collection_id: token_collection.id)

        assert_response :success
        assert_equal JSON.parse(response.body)["name"], "item1"
        assert_equal my_token_id, JSON.parse(response.body)["token_id"].to_i
      end

      test "should return spore cell" do
        token_collection = create :token_collection, name: "token1", standard: "spore"
        address = create :address, is_depositor: true
        my_token_id = 244995949481600724545646750271542270961771653267601098727781219042501243997
        cell = create :cell_output, :with_full_transaction
        create(:cell_datum, cell_output: cell)
        create :token_item, name: "item1", collection_id: token_collection.id, owner_id: address.id,
                            token_id: my_token_id, cell_id: cell.id

        get api_v2_nft_collection_item_url(id: my_token_id, collection_id: token_collection.id)

        assert_response :success
        assert_equal JSON.parse(response.body)["standard"], "spore"
        assert_not_nil JSON.parse(response.body)["cell"]["data"]
      end

      test "should return spore cell when pass hex token_id" do
        token_collection = create :token_collection, name: "token1", standard: "spore"
        address = create :address, is_depositor: true
        my_token_id = "0x008aa9acd3bd41c6e5d051d3cea822772249f2945179dcd4bf97259c474ab45d"
        cell = create :cell_output, :with_full_transaction
        create(:cell_datum, cell_output: cell)
        create :token_item, name: "item1", collection_id: token_collection.id, owner_id: address.id,
                            token_id: my_token_id.hex, cell_id: cell.id

        get api_v2_nft_collection_item_url(id: my_token_id, collection_id: token_collection.id)

        assert_response :success
        assert_equal JSON.parse(response.body)["standard"], "spore"
        assert_not_nil JSON.parse(response.body)["cell"]["data"]
      end
    end
  end
end
