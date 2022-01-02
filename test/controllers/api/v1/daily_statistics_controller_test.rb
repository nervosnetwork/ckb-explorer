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
        15.times do |i|
          create(:daily_statistic, created_at_unixtimestamp: (360 - i).days.ago.to_i)
        end

        daily_statistic_data = DailyStatistic.order(:created_at_unixtimestamp).valid_indicators
        valid_get api_v1_daily_statistic_url("transactions_count")

        assert_equal [%w(transactions_count created_at_unixtimestamp).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal DailyStatisticSerializer.new(daily_statistic_data, params: { indicator: "transactions_count" }).serialized_json, response.body
      end

      test "should return addresses count and timestamp" do
        create_list(:daily_statistic, 15)
        daily_statistic_data = DailyStatistic.order(:id).valid_indicators
        valid_get api_v1_daily_statistic_url("addresses_count")

        assert_equal [%w(addresses_count created_at_unixtimestamp).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal DailyStatisticSerializer.new(daily_statistic_data, params: { indicator: "addresses_count" }).serialized_json, response.body
      end

      test "should return total dao deposit and timestamp" do
        create_list(:daily_statistic, 15)
        valid_get api_v1_daily_statistic_url("total_dao_deposit")

        assert_equal [%w(total_dao_deposit created_at_unixtimestamp).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal DailyStatisticSerializer.new(DailyStatistic.order(:id).valid_indicators, params: { indicator: "total_dao_deposit" }).serialized_json, response.body
      end

      test "should respond with error object when indicator name is invalid" do
        error_object = Api::V1::Exceptions::IndicatorNameInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_daily_statistic_url("dao")

        assert_equal response_json, response.body
      end

      test "should return recent year transactions count and timestamp" do
        target_date = Time.current.beginning_of_year
        i = 1
        o_date = i.days.ago
        while o_date > target_date
          create(:daily_statistic, created_at_unixtimestamp: o_date)
          i += 1
          o_date = i.days.ago
        end
        daily_statistic_data = DailyStatistic.order(:created_at_unixtimestamp).recent_year.valid_indicators
        valid_get api_v1_daily_statistic_url("transactions_count")

        assert_equal [%w(transactions_count created_at_unixtimestamp).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal DailyStatisticSerializer.new(daily_statistic_data, params: { indicator: "transactions_count" }).serialized_json, response.body
        assert_equal ((Time.current - target_date) / (24 * 60 * 60)).to_i, json.dig("data").size
      end

      test "should return recent 90 days average hash rate" do
        100.times do |i|
          create(:daily_statistic, created_at_unixtimestamp: (360 - i).days.ago.to_i)
        end
        daily_statistic_data = DailyStatistic.order(:created_at_unixtimestamp).valid_indicators[-90..-1]
        valid_get api_v1_daily_statistic_url("avg_hash_rate")

        assert_equal [%w(avg_hash_rate created_at_unixtimestamp).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal DailyStatisticSerializer.new(daily_statistic_data, params: { indicator: "avg_hash_rate" }).serialized_json, response.body
        assert_equal 90, json.dig("data").size
      end
    end
  end
end
