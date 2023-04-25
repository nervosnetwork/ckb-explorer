require "test_helper"

module Api
  module V2
    class CollectionsControllerTest < ActionDispatch::IntegrationTest
      def setup
        super
      end
      test "should get index, deposit_to_dao" do
        create :token_collection, name: 'token1'
        create :token_collection, name: 'token2'

        get api_v2_nft_collections_url
        assert_response :success
        assert_equal JSON.parse(response.body)['data'].size, 2
      end

    end
  end
end
