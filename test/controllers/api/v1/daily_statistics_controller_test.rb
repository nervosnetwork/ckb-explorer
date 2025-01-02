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
        get api_v1_daily_statistic_url("transactions_count"),
            headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_daily_statistic_url("transactions_count"),
            headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return transactions count and timestamp" do
        15.times do |i|
          create(:daily_statistic, created_at_unixtimestamp: (359 - i).days.ago.to_i)
        end

        daily_statistic_data = DailyStatistic.order(:created_at_unixtimestamp).valid_indicators
        valid_get api_v1_daily_statistic_url("transactions_count")

        assert_equal [%w(transactions_count created_at_unixtimestamp).sort], json.dig("data").map { |item|
                                                                               item.dig("attributes").keys.sort
                                                                             }.uniq
        assert_equal DailyStatisticSerializer.new(daily_statistic_data, params: { indicator: "transactions_count" }).serialized_json,
                     response.body
      end

      test "should return addresses count and timestamp" do
        create_list(:daily_statistic, 15)
        daily_statistic_data = DailyStatistic.order(created_at_unixtimestamp: :asc).valid_indicators
        valid_get api_v1_daily_statistic_url("addresses_count")

        assert_equal [%w(addresses_count created_at_unixtimestamp).sort],
                     json.dig("data").map { |item|
                       item.dig("attributes").keys.sort
                     }.uniq
        assert_equal DailyStatisticSerializer.new(
          daily_statistic_data, params: { indicator: "addresses_count" }
        ).serialized_json, response.body
      end

      test "should return total dao deposit and timestamp" do
        create_list(:daily_statistic, 15)
        valid_get api_v1_daily_statistic_url("total_dao_deposit")

        assert_equal [%w(total_dao_deposit created_at_unixtimestamp).sort],
                     json.dig("data").map { |item|
                       item.dig("attributes").keys.sort
                     }.uniq

        assert_equal DailyStatisticSerializer.new(
          ::DailyStatistic.order(created_at_unixtimestamp: :asc).valid_indicators,
          params: { indicator: "total_dao_deposit" },
        ).serialized_json, response.body
      end

      test "should respond with error object when indicator name is invalid" do
        error_object = Api::V1::Exceptions::IndicatorNameInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_daily_statistic_url("dao")

        assert_equal response_json, response.body
      end

      test "should return recent all days average hash rate" do
        100.times do |i|
          create(:daily_statistic, created_at_unixtimestamp: (360 - i).days.ago.to_i)
        end
        daily_statistic_data = DailyStatistic.order(:created_at_unixtimestamp).valid_indicators
        valid_get api_v1_daily_statistic_url("avg_hash_rate")

        assert_equal [%w(avg_hash_rate created_at_unixtimestamp).sort], json.dig("data").map { |item|
                                                                          item.dig("attributes").keys.sort
                                                                        }.uniq
        assert_equal DailyStatisticSerializer.new(daily_statistic_data, params: { indicator: "avg_hash_rate" }).serialized_json,
                     response.body
        assert_equal 100, json.dig("data").size
      end

      test "should return ckb_hodl_wave" do
        ckb_hodl_wave = { "over_three_years" => 19531171649.691193,
                          "one_year_to_three_years" => 23338346194.19826,
                          "six_months_to_one_year" => 19609620799.532352,
                          "three_months_to_six_months" => 2236264635.3570275,
                          "one_month_to_three_months" => 814754775.4523662,
                          "one_week_to_one_month" => 456541010.49045384,
                          "day_to_one_week" => 104631888.5063308,
                          "latest_day" => 22211617.27774267,
                          "total_supply" => 40845092357.49983 }
        create(:daily_statistic, created_at_unixtimestamp: 1.day.ago.to_i, ckb_hodl_wave:)
        valid_get api_v1_daily_statistic_url("ckb_hodl_wave")
        assert_equal 1, json.dig("data").size
      end
    end
  end
end
