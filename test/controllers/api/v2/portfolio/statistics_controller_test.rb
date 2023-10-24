require "test_helper"

module Api
  module V2
    module Portfolio
      class StatisticsControllerTest < ActionDispatch::IntegrationTest
        setup do
          ENV["SECRET_KEY_BASE"] = SecureRandom.hex(32)
          @user = create(:user)
          @jwt = PortfolioUtils.generate_jwt({ uuid: @user.uuid })
        end

        test "should respond with error object when addresses inconsistencies detected" do
          error_object = Api::V2::Exceptions::PortfolioLatestDiscrepancyError.new
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          get api_v2_portfolio_statistics_url(address: "ckt1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323k5v49yzmvm0q0kfqw0hk0kyal6z32nwjvcqqr7qyzq8yqtec2wj"),
              headers: { "Authorization": @jwt }
          assert_equal response_json, response.body
        end

        test "should return statistic when address inconsistencies resolved" do
          address_hash = "ckt1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323k5v49yzmvm0q0kfqw0hk0kyal6z32nwjvcqqr7qyzq8yqtec2wj"
          address = create(:address, address_hash: address_hash)
          create(:portfolio, user: @user, address: address)
          portfolio_statistic = create(:portfolio_statistic, user: @user)

          response_json = {
            data: {
              portfolio_statistic: {
                id: portfolio_statistic.id,
                capacity: portfolio_statistic.capacity,
                occupied_capacity: portfolio_statistic.occupied_capacity,
                dao_deposit: portfolio_statistic.dao_deposit,
                interest: portfolio_statistic.interest,
                unclaimed_compensation: portfolio_statistic.unclaimed_compensation
              }
            }
          }.as_json

          get api_v2_portfolio_statistics_url(address: address_hash), headers: {
            "Authorization": @jwt, "Accept": "application/json"
          }
          assert_equal response_json, json
        end
      end
    end
  end
end
