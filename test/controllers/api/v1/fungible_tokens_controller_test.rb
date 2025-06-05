require "test_helper"

module Api
  module V1
    class FungibleTokensControllerTest < ActionDispatch::IntegrationTest
      setup do
        create(:udt, published: true, udt_type: "xudt_compatible")
        create(:udt, published: true, udt_type: "xudt")
        @ssri = create(:udt, published: true, udt_type: "ssri")
        create(:udt, published: true, udt_type: "sudt")
      end

      test "should return all udts" do
        valid_get api_v1_fungible_tokens_url

        assert_response :success
        assert 4, json["data"].length
      end

      test "should return ssri udt" do
        valid_get api_v1_fungible_token_url(@ssri.type_hash)

        assert_response :success
        assert "ssri", json["data"]["udt_type"]
      end
    end
  end
end
