require "test_helper"

module Api
  module V1
    module External
      class StatsControllerTest < ActionDispatch::IntegrationTest
        test "should return tip block number when call show action and id is equal to tip_block_number" do
          prepare_node_data
          get api_v1_external_stat_url("tip_block_number")

          assert_equal "30", response.body
        end

        test "should return empty string when call show action but id is not equal to block number" do
          get api_v1_external_stat_url("tip_block_number")

          assert_empty response.body
        end
      end
    end
  end
end
