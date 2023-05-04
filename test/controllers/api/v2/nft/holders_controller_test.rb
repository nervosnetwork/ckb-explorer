require "test_helper"

module Api
  module V2
    class NFT::HoldersControllerTest < ActionDispatch::IntegrationTest
      def setup
        super
        @token_collection = create :token_collection, name: 'token1'
        @owner_address1 = create :address, is_depositor: true
        @owner_address2 = create :address, is_depositor: true

      end
      test "should get index" do

        @token_item1 = create :token_item, name: 'item', collection_id: @token_collection.id,
          owner_id: @owner_address1.id
        @token_item2 = create :token_item, name: 'item', collection_id: @token_collection.id,
          owner_id: @owner_address2.id

        get api_v2_nft_collection_holders_url(collection_id: @token_collection.id)
        assert_response :success

        assert_equal 2, JSON.parse(response.body)['data'].size
        assert_equal 1, JSON.parse(response.body)['data'][@owner_address1.address_hash]
      end

    end
  end
end
