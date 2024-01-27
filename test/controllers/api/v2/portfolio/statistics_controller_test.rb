require "test_helper"

module Api
  module V2
    module Portfolio
      class StatisticsControllerTest < ActionDispatch::IntegrationTest
        setup do
          ENV["AUTH_ACCESS_EXPIRE"] = "1296000"
          ENV["SECRET_KEY_BASE"] = SecureRandom.hex(32)
          @user = create(:user)
          @jwt = PortfolioUtils.generate_jwt({ uuid: @user.uuid })
        end

        test "should respond with error object when addresses inconsistencies detected" do
          address = "ckt1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323k5v49yzmvm0q0kfqw0hk0kyal6z32nwjvcqqr7qyzq8yqtec2wj"
          error_object = Api::V2::Exceptions::PortfolioLatestDiscrepancyError.new(address)
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          get api_v2_portfolio_statistics_url(latest_address: address),
              headers: { "Authorization": @jwt }
          assert_equal response_json, response.body
        end

        test "should return statistic when address inconsistencies resolved" do
          address_hash = "ckt1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323k5v49yzmvm0q0kfqw0hk0kyal6z32nwjvcqqr7qyzq8yqtec2wj"
          address = create(:address, address_hash: address_hash)
          create(:portfolio, user: @user, address: address)

          response_json = {
            data: {
              balance: address.balance.to_s,
              balance_occupied: address.balance_occupied.to_s,
              dao_deposit: address.dao_deposit.to_s,
              interest: address.interest.to_s,
              dao_compensation: (address.interest.to_i + address.unclaimed_compensation.to_i).to_s
            }
          }.as_json

          get api_v2_portfolio_statistics_url(latest_address: address_hash), headers: {
            "Authorization": @jwt, "Accept": "application/json"
          }
          assert_equal response_json, json
        end
      end
    end
  end
end
