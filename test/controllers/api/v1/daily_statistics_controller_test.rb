require "test_helper"

module Api
  module V1
    class DailyStatisticsControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call index" do
        valid_get api_v1_daily_statistic_url("transactions_count")

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_daily_statistic_url("transactions_count"), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_daily_statistic_url("transactions_count"), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_daily_statistic_url("transactions_count"), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_daily_statistic_url("transactions_count"), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return transactions count and timestamp" do
        daily_statistic_data = create_list(:daily_statistic, 15)
        valid_get api_v1_daily_statistic_url("transactions_count")

        assert_equal [%w(transactions_count created_at_unixtimestamp).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal DailyStatisticSerializer.new(daily_statistic_data, params: { indicator: "transactions_count" }).serialized_json, response.body
      end

      test "should return addresses count and timestamp" do
        daily_statistic_data = create_list(:daily_statistic, 15)
        valid_get api_v1_daily_statistic_url("addresses_count")

        assert_equal [%w(addresses_count created_at_unixtimestamp).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal DailyStatisticSerializer.new(daily_statistic_data, params: { indicator: "addresses_count" }).serialized_json, response.body
      end

      test "should return total dao deposit and timestamp" do
        daily_statistic_data = create_list(:daily_statistic, 15)
        valid_get api_v1_daily_statistic_url("total_dao_deposit")

        assert_equal [%w(total_dao_deposit created_at_unixtimestamp).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal DailyStatisticSerializer.new(daily_statistic_data, params: { indicator: "total_dao_deposit" }).serialized_json, response.body
      end

      test "should respond with error object when indicator name is invalid" do
        error_object = Api::V1::Exceptions::IndicatorNameInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_daily_statistic_url("dao")

        assert_equal response_json, response.body
      end
    end
  end
end
