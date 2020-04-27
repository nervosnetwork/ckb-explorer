require "test_helper"

module Api
  module V1
    class DistributionDataControllerTest < ActionDispatch::IntegrationTest
      setup do
        DistributionData.any_instance.stubs(:id).returns(1)
        create(:daily_statistic, address_balance_distribution: [[100, 1314, 19702], [1000, 3112, 22814], [10000, 1818, 24632], [100000, 2201, 26833], [1000000, 1780, 28613], [10000000, 724, 29337], [100000000, 268, 29605], [1000000000, 42, 29647], [10000000000, 3, 29650]])
      end

      test "should set right content type when call show" do
        valid_get api_v1_distribution_datum_url("address_balance_distribution")

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_distribution_datum_url("address_balance_distribution"), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_distribution_datum_url("address_balance_distribution"), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_distribution_datum_url("address_balance_distribution"), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_distribution_datum_url("address_balance_distribution"), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return address balance distribution when indicator is address_balance_distribution" do
        valid_get api_v1_distribution_datum_url("address_balance_distribution")
        distribution_data = DistributionData.new

        response_json = DistributionDataSerializer.new(distribution_data, params: { indicator: "address_balance_distribution" }).serialized_json

        assert_equal response_json, response.body
      end

      test "should return block time distribution when indicator is block_time_distribution" do
        valid_get api_v1_distribution_datum_url("block_time_distribution")
        distribution_data = DistributionData.new

        response_json = DistributionDataSerializer.new(distribution_data, params: { indicator: "block_time_distribution" }).serialized_json

        assert_equal response_json, response.body
      end

      test "should respond with error object when indicator name is invalid" do
        error_object = Api::V1::Exceptions::IndicatorNameInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_distribution_datum_url("dao")

        assert_equal response_json, response.body
      end
    end
  end
end
