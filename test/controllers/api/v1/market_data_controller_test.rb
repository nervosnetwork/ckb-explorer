require "test_helper"

module Api
  module V1
    class MarketDataControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call index" do
        create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
        valid_get api_v1_market_datum_url("circulating_supply")

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_market_datum_url("circulating_supply"), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::WrongContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_market_datum_url("circulating_supply"), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_market_datum_url("circulating_supply"), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::WrongAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_market_datum_url("circulating_supply"), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return current circulating supply" do
        create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
        valid_get api_v1_market_datum_url("circulating_supply")
        latest_dao = Block.recent.pick(:dao)
        parsed_dao = CkbUtils.parse_dao(latest_dao)
        result = parsed_dao.c_i - (336 * 10**16 * 0.25).to_d
        expected_circulating_supply = (result / 10**8).to_s

        assert_equal expected_circulating_supply, json
      end
    end
  end
end
