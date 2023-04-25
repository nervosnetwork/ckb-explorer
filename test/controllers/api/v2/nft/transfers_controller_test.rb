require "test_helper"

module Api
  module V2
    class NFT::TransfersControllerTest < ActionDispatch::IntegrationTest
      def setup
        super
      end
      test "should get index" do
        token_collection = create :token_collection, name: 'token1'
        from_address = create :address, is_depositor: true
        to_address = create :address, is_depositor: true

        token_item = create :token_item, name: 'item', collection_id: token_collection.id, owner_id: from_address.id
        tx = create :ckb_transaction, :with_single_output

        token_transfer = create :token_transfer, item_id: token_item.id, from_id: from_address.id, to_id: to_address.id,
          action: :normal, transaction_id: tx.id

        get api_v2_nft_transfers_url(collection_id: token_collection.id, token_id: token_item.id,
                                     from: from_address.address_hash,
                                     to: to_address.address_hash)
        assert_response :success
        assert_equal 1, JSON.parse(response.body)['data'].size
        assert_equal token_transfer.id, JSON.parse(response.body)['data'][0]['item']['id']
      end

      test "should get show" do
        sn = '001-sn'
        name = 'token-with-sn'
        create :token_collection, name: name, sn: sn

        get api_v2_nft_collection_url(id: sn)

        assert_response :success
        assert_equal JSON.parse(response.body)['name'], name
      end

    end
  end
end
