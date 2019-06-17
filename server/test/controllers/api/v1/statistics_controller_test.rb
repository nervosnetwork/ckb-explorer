require "test_helper"

module Api
  module V1
    class StatisticsControllerTest < ActionDispatch::IntegrationTest
      setup do
        CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(100)
        CkbSync::Api.any_instance.stubs(:get_current_epoch).returns(
          CKB::Types::Epoch.new(
            block_reward: "250000000000",
            difficulty: "0x1000",
            last_block_hash_in_previous_epoch: "0x0000000000000000000000000000000000000000000000000000000000000000",
            length: "2000",
            number: "0",
            remainder_reward: "0",
            start_number: "0"
          )
        )
      end

      test "should get success code when call index" do
        valid_get api_v1_statistics_url

        assert_response :success
      end

      test "should set right content type when call index" do
        valid_get api_v1_statistics_url

        assert_equal "application/vnd.api+json", response.content_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_statistics_url, headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::WrongContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_statistics_url, headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_statistics_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::WrongAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_statistics_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "the returned statistic info should contain right keys" do
        valid_get api_v1_statistics_url

        assert_equal %w(average_block_time current_epoch_difficulty hash_rate tip_block_number), json.dig("data", "attributes").keys.sort
      end

      test "should return right statistic info" do
        statistic_info = StatisticInfo.new

        valid_get api_v1_statistics_url

        assert_equal IndexStatisticSerializer.new(statistic_info).serialized_json, response.body
      end
      test "should get success code when call show" do
        valid_get api_v1_statistic_url("miner_ranking")

        assert_response :success
      end

      test "the returned miner ranking info should contain right keys" do
        CkbSync::Api.any_instance.stubs(:get_epoch_by_number).with(0).returns(
          CKB::Types::Epoch.new(
            block_reward: "250000000000",
            difficulty: "0x1000",
            last_block_hash_in_previous_epoch: "0x0000000000000000000000000000000000000000000000000000000000000000",
            length: "2000",
            number: "0",
            remainder_reward: "0",
            start_number: "0"
          )
        )
        generate_miner_ranking_related_data

        valid_get api_v1_statistic_url("miner_ranking")

        assert_equal %w(ranking), json.dig("data", "attributes").keys.sort
      end

      test "should return right ranking" do
        CkbSync::Api.any_instance.stubs(:get_epoch_by_number).with(0).returns(
          CKB::Types::Epoch.new(
            block_reward: "250000000000",
            difficulty: "0x1000",
            last_block_hash_in_previous_epoch: "0x0000000000000000000000000000000000000000000000000000000000000000",
            length: "2000",
            number: "0",
            remainder_reward: "0",
            start_number: "0"
          )
        )
        generate_miner_ranking_related_data
        ranking = MinerRanking.new

        valid_get api_v1_statistic_url("miner_ranking")

        assert_equal MinerRankingSerializer.new(ranking).serialized_json, response.body
      end

      test "the returned empty array when event not start" do
        CkbSync::Api.any_instance.stubs(:get_epoch_by_number).with(0).returns(
          CKB::Types::Epoch.new(
            block_reward: "250000000000",
            difficulty: "0x1000",
            last_block_hash_in_previous_epoch: "0x0000000000000000000000000000000000000000000000000000000000000000",
            length: "2000",
            number: "0",
            remainder_reward: "0",
            start_number: "0"
          )
        )
        generate_miner_ranking_related_data(1550578400000)

        valid_get api_v1_statistic_url("miner_ranking")

        assert_equal [], json.dig("data", "attributes", "ranking")
      end
    end
  end
end
