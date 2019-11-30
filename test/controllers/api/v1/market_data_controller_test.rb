require "test_helper"

module Api
  module V1
    class MarketDataControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call index" do
        create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
        valid_get api_v1_market_datum_url("circulating_supply")

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should return current total supply" do
        create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
        valid_get api_v1_market_datum_url("total_supply")
        latest_dao = Block.recent.pick(:dao)
        parsed_dao = CkbUtils.parse_dao(latest_dao)
        result = parsed_dao.c_i - (336 * 10**16 * 0.25).to_d
        expected_total_supply = (result / 10**8).to_s

        assert_equal expected_total_supply, json
      end

      test "should return current circulating supply" do
        create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
        valid_get api_v1_market_datum_url("circulating_supply")
        MarketData.new("circulating_supply").call

        assert_equal MarketData.new("circulating_supply").call.to_s, json
      end
    end
  end
end
