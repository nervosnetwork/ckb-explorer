require "test_helper"

module Api
  module V2
    class ItemsControllerTest < ActionDispatch::IntegrationTest
      def setup
        super

      end

      test "should get index with collection id" do
        token_collection = create :token_collection, name: 'token1'
        address = create(:address, is_depositor: true)

        create :token_item, name: 'item1', collection_id: token_collection.id, owner_id: address.id
        create :token_item, name: 'item2', collection_id: token_collection.id, owner_id: address.id

        get api_v2_nft_items_url(collection_id: token_collection.id)
        assert_response :success
        assert_equal JSON.parse(response.body)['data'].size, 2
      end

      test "should get index with collection sn" do
        sn = 'iam-an-sn'
        token_collection = create :token_collection, name: 'token1', sn: sn
        address = create(:address, is_depositor: true)

        create :token_item, name: 'item1', collection_id: token_collection.id, owner_id: address.id
        create :token_item, name: 'item2', collection_id: token_collection.id, owner_id: address.id

        get api_v2_nft_items_url(collection_id: sn)
        assert_response :success
        assert_equal JSON.parse(response.body)['data'].size, 2
      end

      test "should get show" do
        #sn = '001-sn'
        #name = 'token-with-sn'
        #create :token_collection, name: name, sn: sn

        #get api_v2_nft_collection_url(id: sn)

        #assert_response :success
        #assert_equal JSON.parse(response.body)['name'], name
      end

    end
  end
end
