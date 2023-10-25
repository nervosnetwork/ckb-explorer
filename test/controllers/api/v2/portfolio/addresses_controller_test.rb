require "test_helper"

module Api
  module V2
    module Portfolio
      class AddressesControllerTest < ActionDispatch::IntegrationTest
        setup do
          ENV["SECRET_KEY_BASE"] = SecureRandom.hex(32)
        end

        test "should respond with error object when address parsed failed" do
          error_object = Api::V2::Exceptions::SyncPortfolioAddressesError.new
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          user = create(:user)
          jwt = PortfolioUtils.generate_jwt({ uuid: user.uuid })

          post api_v2_portfolio_addresses_url(addresses: ["test"]), headers: { "Authorization": jwt }

          assert_equal response_json, response.body
        end

        test "should return 204 status code when sync addresses success" do
          user = create(:user)
          jwt = PortfolioUtils.generate_jwt({ uuid: user.uuid })
          address = "ckt1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323k5v49yzmvm0q0kfqw0hk0kyal6z32nwjvcqqr7qyzq8yqtec2wj"

          assert_difference -> { user.reload.portfolios.count }, 1 do
            post api_v2_portfolio_addresses_url(addresses: [address]), headers: { "Authorization": jwt }
          end

          assert_response :no_content
        end
      end
    end
  end
end
