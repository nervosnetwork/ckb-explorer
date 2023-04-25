require "test_helper"

module Api
  module V2
    class NFT::CollectionsControllerTest < ActionDispatch::IntegrationTest
      def setup
        super
      end
      test "should get index" do
        create :token_collection, name: 'token1'
        create :token_collection, name: 'token2'

        get api_v2_nft_collections_url
        assert_response :success
        assert_equal JSON.parse(response.body)['data'].size, 2
      end

      test "should get show" do
        sn = '001-sn'
        name = 'token-with-sn'
        create :token_collection, name: name, sn: sn

        get api_v2_nft_collection_url(id: sn)

        assert_response :success
        assert_equal JSON.parse(response.body)['name'], name
      end

    end
  end
end
