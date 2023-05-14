require "test_helper"

module Api
  module V2::Nft
    class TransfersControllerTest < ActionDispatch::IntegrationTest

      test "should get success code when call show" do

        from = create :address
        to = create :address
        owner = create :address
        token_collection = create :token_collection
        token_item = create :token_item, collection_id: token_collection.id, owner_id: owner.id

        ckb_transaction = create :ckb_transaction, :with_single_output

        token_transfer = create :token_transfer, item_id: token_item.id, from_id: from.id, to_id: to.id, transaction_id:  ckb_transaction.id

        valid_get api_v2_nft_transfer_url(collection_id: token_collection.sn, id: token_transfer.id)

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
