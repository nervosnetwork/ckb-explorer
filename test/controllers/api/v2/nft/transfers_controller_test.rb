require "test_helper"

module Api
  module V2::Nft
    class TransfersControllerTest < ActionDispatch::IntegrationTest

      setup do
        from = create :address
        to = create :address
        owner = create :address
        @token_collection = create :token_collection
        token_item = create :token_item, collection_id: @token_collection.id, owner_id: owner.id
        ckb_transaction = create :ckb_transaction, :with_single_output
        @token_transfer = create :token_transfer, item_id: token_item.id, from_id: from.id, to_id: to.id, transaction_id:  ckb_transaction.id
      end

      test "should get index" do

        valid_get api_v2_nft_transfers_url(collection_id: @token_collection.sn)
        assert_response :success
      end

      test "should get show" do

        valid_get api_v2_nft_transfer_url(collection_id: @token_collection.sn, id: @token_transfer.id)
        assert_response :success
      end

      test "should get download_csv, by date" do

        valid_get download_csv_api_v2_nft_transfers_url(collection_id: @token_collection.sn, start_date: 1.day.ago.strftime("%Y-%m-%d"))
        assert_response :success
      end

      test "should get download_csv, by block_number" do

        valid_get download_csv_api_v2_nft_transfers_url(collection_id: @token_collection.sn, start_number: 8, end_number: 12)
        assert_response :success
      end
    end
  end
end
