require "test_helper"

module Api
  module V1
    class StatisticsControllerTest < ActionDispatch::IntegrationTest
      setup do
        CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(100)
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
