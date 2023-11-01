require "test_helper"

module Api
  module V2
    module Portfolio
      class UdtAccountsControllerTest < ActionDispatch::IntegrationTest
        setup do
          ENV["SECRET_KEY_BASE"] = SecureRandom.hex(32)
          @user = create(:user)
          @jwt = PortfolioUtils.generate_jwt({ uuid: user.uuid })
        end

        test "should return empty result when user sudt accounts are empty" do
          get api_v2_portfolio_udt_accounts_url(cell_type: "sudt", published: true),
              headers: { "Authorization": jwt }

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
