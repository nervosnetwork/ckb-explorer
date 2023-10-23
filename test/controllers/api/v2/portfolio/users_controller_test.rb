require "test_helper"

module Api
  module V2
    module Portfolio
      class UsersControllerTest < ActionDispatch::IntegrationTest
        setup do
          ENV["SECRET_KEY_BASE"] = SecureRandom.hex(32)
        end

        test "should respond with error object when use not exists" do
          error_object = Api::V2::Exceptions::UserNotExistError.new("validate jwt")
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          jwt = PortfolioUtils.generate_jwt({ uuid: "test" })
          put api_v2_portfolio_user_url, headers: { "Authorization": jwt }

          assert_equal response_json, response.body
        end

        test "should respond with error object when jwt expired" do
          user = create(:user)

          error_object = Api::V2::Exceptions::DecodeJWTFailedError.new("Signature has expired")
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          exp = Time.current.to_i - ENV["AUTH_ACCESS_EXPIRE"].to_i
          jwt = PortfolioUtils.generate_jwt({ uuid: user.uuid, exp: exp })
          put api_v2_portfolio_user_url, headers: { "Authorization": jwt }

          assert_equal response_json, response.body
        end

        test "should respond with error object when jwt decode failed" do
          error_object = Api::V2::Exceptions::DecodeJWTFailedError.new("Not enough or too many segments")
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          put api_v2_portfolio_user_url, headers: { "Authorization": "test" }

          assert_equal response_json, response.body
        end

        test "should return 204 status code when update name success" do
          user = create(:user)
          jwt = PortfolioUtils.generate_jwt({ uuid: user.uuid })

          put api_v2_portfolio_user_url(name: "Jack"), headers: { "Authorization": jwt }

          assert_equal "Jack", user.reload.name
          assert_response :no_content
        end
      end
    end
  end
end
