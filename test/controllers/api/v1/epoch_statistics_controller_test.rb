require "test_helper"

module Api
  module V1
    class EpochStatisticsControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call index" do
        valid_get api_v1_epoch_statistic_url("difficulty-uncle_rate")

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_epoch_statistic_url("difficulty-uncle_rate"), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_epoch_statistic_url("difficulty-uncle_rate"), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_epoch_statistic_url("difficulty-uncle_rate"), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_epoch_statistic_url("difficulty-uncle_rate"), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return difficulty, uncle_rate and epoch number" do
        (1..15).each {|number| create(:epoch_statistic, epoch_number: number)}
        block_statistic_data = EpochStatistic.order(epoch_number: :desc).reverse
        valid_get api_v1_epoch_statistic_url("difficulty-uncle_rate")

        assert_equal [%w(difficulty uncle_rate epoch_number largest_block largest_tx).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal EpochStatisticSerializer.new(block_statistic_data, { params: { indicator: "difficulty-uncle_rate" } }).serialized_json, response.body
      end

      test "should return difficulty, hash_rate and epoch number" do
        (1..15).each {|number| create(:epoch_statistic, epoch_number: number)}
        block_statistic_data = EpochStatistic.order(epoch_number: :desc).reverse
        valid_get api_v1_epoch_statistic_url("difficulty-hash_rate")

        assert_equal [%w(difficulty hash_rate epoch_number largest_block largest_tx).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal EpochStatisticSerializer.new(block_statistic_data, { params: { indicator: "difficulty-hash_rate" } }).serialized_json, response.body
      end

      test "should return epoch_time and epoch_length" do
        (1..15).each {|number| create(:epoch_statistic, epoch_number: number)}
        block_statistic_data = EpochStatistic.order(epoch_number: :desc).reverse
        valid_get api_v1_epoch_statistic_url("epoch_time-epoch_length")

        assert_equal [%w(epoch_length epoch_time epoch_number largest_block largest_tx).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal EpochStatisticSerializer.new(block_statistic_data, { params: { indicator: "epoch_time-epoch_length" } }).serialized_json, response.body
      end

      test "should return latest 10 epoch statistics when limit is not present" do
        (1..15).each {|number| create(:epoch_statistic, epoch_number: number)}
        block_statistic_data = EpochStatistic.order(epoch_number: :desc).limit(10).reverse
        valid_get api_v1_epoch_statistic_url("difficulty-uncle_rate", limit: 10)

        assert_equal [%w(difficulty uncle_rate epoch_number largest_block largest_tx).sort], json.dig("data").map { |item| item.dig("attributes").keys.sort }.uniq
        assert_equal EpochStatisticSerializer.new(block_statistic_data, { params: { indicator: "difficulty-uncle_rate" } }).serialized_json, response.body
      end

      test "should respond with error object when indicator name is invalid" do
        error_object = Api::V1::Exceptions::IndicatorNameInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_epoch_statistic_url("hash_rates")

        assert_equal response_json, response.body
      end
    end
  end
end
