require "test_helper"

module Api
  module V1
    class ApplicationControllerTest < ActionDispatch::IntegrationTest
      test "visit root should call homepage action" do
        valid_get root_url
        expected_message = "Please read more API info at https://github.com/nervosnetwork/ckb-explorer/"

        assert_equal expected_message, json["message"]
      end

      test "visit not exist url will get 404 and routing error message" do
        valid_get "/app"

        assert_response :not_found
        assert_equal "app", json["message"]
      end
    end
  end
end
