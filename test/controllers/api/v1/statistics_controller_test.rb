require "test_helper"

module Api
  module V1
    class StatisticsControllerTest < ActionDispatch::IntegrationTest
      setup do
        CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(100)
        CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(
          OpenStruct.new(alerts: OpenStruct.new(message: "test"))
        )
        CkbSync::Api.any_instance.stubs(:get_current_epoch).returns(
          CKB::Types::Epoch.new(
            compact_target: "0x1000",
            length: "0x07d0",
            number: "0x0",
            start_number: "0x0"
          )
        )
        # StatisticInfo.any_instance.stubs(:id).returns(1)
      end

      test "should get success code when call index" do
        create(:block)
        StatisticInfo.default.reset_all!
        valid_get api_v1_statistics_url

        assert_response :success
      end

      test "should set right content type when call index" do
        create(:block)
        StatisticInfo.default.reset_all!
        valid_get api_v1_statistics_url

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_statistics_url, headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_statistics_url, headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_statistics_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_statistics_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "the returned statistic info should contain right keys" do
        create_list(:block, 15, :with_block_hash)
        StatisticInfo.default.reset_all!
        valid_get api_v1_statistics_url

        assert_equal %w(average_block_time current_epoch_difficulty hash_rate tip_block_number epoch_info estimated_epoch_time transactions_last_24hrs transactions_count_per_minute reorg_started_at).sort,
                     json.dig("data", "attributes").keys.sort
      end

      test "should return right index statistic info" do
        create_list(:block, 15, :with_block_hash)
        statistic_info = StatisticInfo.default
        statistic_info.reset_all!
        valid_get api_v1_statistics_url

        assert_equal IndexStatisticSerializer.new(statistic_info).serialized_json, response.body
      end

      test "should get success code when call show" do
        ENV["MINER_RANKING_EVENT"] = "on"
        StatisticInfo.default.reset_all!
        valid_get api_v1_statistic_url("miner_ranking")

        assert_response :success
      end

      test "the returned miner ranking info should contain right keys" do
        ENV["MINER_RANKING_EVENT"] = "on"

        CkbSync::Api.any_instance.stubs(:get_epoch_by_number).with(0).returns(
          CKB::Types::Epoch.new(
            compact_target: "0x1000",
            length: "0x07d0",
            number: "0x0",
            start_number: "0x0"
          )
        )
        generate_miner_ranking_related_data
        StatisticInfo.default.reset_all!
        valid_get api_v1_statistic_url("miner_ranking")

        assert_equal %w(miner_ranking), json.dig("data", "attributes").keys.sort
      end

      test "should return right ranking" do
        ENV["MINER_RANKING_EVENT"] = "on"
        CkbSync::Api.any_instance.stubs(:get_epoch_by_number).with(0).returns(
          CKB::Types::Epoch.new(
            compact_target: "0x1000",
            length: "0x07d0",
            number: "0x0",
            start_number: "0x0"
          )
        )
        generate_miner_ranking_related_data
        statistic_info = StatisticInfo.default
        statistic_info.reset_all!
        valid_get api_v1_statistic_url("miner_ranking")
        assert_equal StatisticSerializer.new(statistic_info, { params: { info_name: "miner_ranking" } }).serialized_json,
                     response.body
      end

      test "the returned empty array when event not start" do
        ENV["MINER_RANKING_EVENT"] = "on"
        CkbSync::Api.any_instance.stubs(:get_epoch_by_number).with(0).returns(
          CKB::Types::Epoch.new(
            compact_target: "0x1000",
            length: "0x07d0",
            number: "0x0",
            start_number: "0x0"
          )
        )
        generate_miner_ranking_related_data(1550578400000)
        StatisticInfo.default.reset! :miner_ranking
        valid_get api_v1_statistic_url("miner_ranking")

        assert_equal [], json.dig("data", "attributes", "miner_ranking")
      end

      test "should return right statistic info" do
        create(:block)
        ENV["MINER_RANKING_EVENT"] = "on"
        tip_block_number = 101
        CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(tip_block_number)
        statistic_info = StatisticInfo.default
        statistic_info.reset_all!
        valid_get api_v1_statistic_url("tip_block_number")

        assert_equal StatisticSerializer.new(statistic_info, { params: { info_name: "tip_block_number" } }).serialized_json,
                     response.body
      end

      test "should return tip block number when param is tip_block_number" do
        Block.delete_all
        tip_block_number = 101
        create(:block, number: tip_block_number)

        valid_get api_v1_statistic_url("tip_block_number")

        assert_equal tip_block_number, json.dig("data", "attributes", "tip_block_number")
      end

      test "should return average block time when param is average_block_time" do
        average_block_time = "10000"
        create_list(:block, 15, :with_block_hash)
        StatisticInfo.any_instance.stubs(:average_block_time).returns(average_block_time)

        valid_get api_v1_statistic_url("average_block_time")

        assert_equal average_block_time, json.dig("data", "attributes", "average_block_time")
      end

      test "should return current epoch difficulty when param is current_epoch_difficulty" do
        current_epoch_difficulty = 100_000
        StatisticInfo.any_instance.stubs(:current_epoch_difficulty).returns(current_epoch_difficulty)

        valid_get api_v1_statistic_url("current_epoch_difficulty")

        assert_equal current_epoch_difficulty, json.dig("data", "attributes", "current_epoch_difficulty")
      end

      test "should return current hash rate when param is hash_rate" do
        hash_rate = 1_000_000
        StatisticInfo.any_instance.stubs(:hash_rate).returns(hash_rate)

        valid_get api_v1_statistic_url("hash_rate")

        assert_equal hash_rate, json.dig("data", "attributes", "hash_rate")
      end

      test "should return current blockchain info when param is blockchain_info" do
        blockchain_info = CKB::Types::ChainInfo.new(
          is_initial_block_download: false,
          epoch: "0x1",
          difficulty: "0x100",
          median_time: "0x16bd6605e65",
          chain: "ckb_testnet",
          alerts: []
        )
        StatisticInfo.any_instance.stubs(:blockchain_info).returns(blockchain_info)
        statistic_info = StatisticInfo.default
        statistic_info.reset! :blockchain_info
        valid_get api_v1_statistic_url("blockchain_info")

        assert_equal StatisticSerializer.new(statistic_info, { params: { info_name: "blockchain_info" } }).serialized_json,
                     response.body
      end

      test "should return top 50 addresses balance list when param is address balance ranking" do
        create_list(:address, 100).each.with_index(1) do |address, index|
          address.update(balance: index * 100)
        end
        statistic_info = StatisticInfo.default
        statistic_info.reset! :address_balance_ranking
        valid_get api_v1_statistic_url("address_balance_ranking")
        assert_equal %w(ranking address balance).sort,
                     json.dig("data", "attributes", "address_balance_ranking").map(&:keys).uniq.flatten.sort
        assert_equal StatisticSerializer.new(statistic_info, { params: { info_name: "address_balance_ranking" } }).serialized_json,
                     response.body
      end

      test "should respond with error object when statistic info name is invalid" do
        error_object = Api::V1::Exceptions::StatisticInfoNameInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_statistic_url("hash_rates")

        assert_equal response_json, response.body
      end
    end
  end
end
