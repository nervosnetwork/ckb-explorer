require "test_helper"

module Api
  module V1
    class DaoDepositorsControllerTest < ActionDispatch::IntegrationTest
      test "should get index" do
        get api_v1_dao_depositors_index_url
        assert_response :success
      end
    end
  end
end

