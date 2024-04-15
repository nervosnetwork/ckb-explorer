require "test_helper"

module Api
  module V2
    module Portfolio
      class SessionsControllerTest < ActionDispatch::IntegrationTest
        setup do
          ENV["CKB_NET_MODE"] = "testnet"
          ENV["AUTH_ACCESS_EXPIRE"] = "1296000"
          ENV["SECRET_KEY_BASE"] = SecureRandom.hex(32)
          @message = "0x95e919c41e1ae7593730097e9bb1185787b046ae9f47b4a10ff4e22f9c3e3eab"
          @signature = "0x1e94db61cff452639cf7dd991cf0c856923dcf74af24b6f575b91479ad2c8ef40769812d1cf1fd1a15d2f6cb9ef3d91260ef27e65e1f9be399887e9a5447786301"
          @address = "ckt1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqfkcv576ccddnn4quf2ga65xee2m26h7nq4sds0r"
        end

        test "should respond with error object when address does not match the testnet" do
          error_object = Api::V2::Exceptions::AddressNotMatchEnvironmentError.new(ENV["CKB_NET_MODE"])
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          post api_v2_portfolio_sessions_url,
               params: { address: "test", message: @message, signature: @signature }

          assert_equal response_json, response.body
        end

        test "should respond with error object when message is wrong" do
          error_object = Api::V2::Exceptions::InvalidPortfolioMessageError.new
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          post api_v2_portfolio_sessions_url,
               params: { address: @address, message: "test", signature: @signature }

          assert_equal response_json, response.body
        end

        test "should respond with error object when signature is wrong" do
          error_object = Api::V2::Exceptions::InvalidPortfolioSignatureError.new
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          post api_v2_portfolio_sessions_url,
               params: { address: @address, message: @message, signature: "test" }

          assert_equal response_json, response.body
        end

        test "should create user when user is not exists" do
          assert_difference -> { User.count }, 1 do
            post api_v2_portfolio_sessions_url,
                 params: { address: @address, message: @message, signature: @signature }
          end
        end

        test "should return jwt when user sign in" do
          post api_v2_portfolio_sessions_url,
               params: { address: @address, message: @message, signature: @signature }

          access_expire = Time.current.to_i + ENV["AUTH_ACCESS_EXPIRE"].to_i
          payload = { uuid: User.find_by(identifier: @address).uuid, exp: access_expire }
          jwt = PortfolioUtils.generate_jwt(payload)

          assert_equal jwt, json["jwt"]
          ENV["CKB_NET_MODE"] = "mainnet"
        end
      end
    end
  end
end
