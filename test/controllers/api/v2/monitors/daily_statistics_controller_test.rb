require "test_helper"

module Api
  module V2
    module Monitors
      class DailyStatisticsControllerTest < ActionDispatch::IntegrationTest
        setup do
          create(:daily_statistic, created_at_unixtimestamp: Time.now.yesterday.to_i)
        end

        test "should get the last daily_statistics" do
          VCR.use_cassette("get the last daily_statistics") do
            get '/api/v2/monitors/daily_statistics', headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }
            data = JSON.parse(response.body)

            assert_equal 'ok', data["status"]
            assert_response :success
          end
        end

      end
    end
  end
end
