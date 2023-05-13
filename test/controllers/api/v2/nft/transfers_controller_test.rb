require "test_helper"

module Api
  module V2::Nft
    # TODO not finish yet
    class TransfersControllerTest < ActionDispatch::IntegrationTest

      test "should get success code when call show" do
        udt = create(:udt, published: true)

        # TODO
        token_collection = create(:token_collection)
        token_item = create(:token_item)
        token_transfer = create(:token_transfer)
        from = create(:address)
        to = create(:address)

        valid_get api_v1_udt_url(udt.type_hash)

        assert_response :success
      end

      test "should get download_csv" do
        udt = create(:udt, :with_transactions, published: true)

        valid_get download_csv_api_v1_udts_url(id: udt.type_hash, start_data: (Time.now - 10), end_date: Time.now)

        assert_response :success
      end
    end
  end
end
