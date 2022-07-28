# == Schema Information
#
# Table name: token_transfers
#
#  id             :bigint           not null, primary key
#  item_id        :integer
#  from_id        :integer
#  to_id          :integer
#  transaction_id :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  action         :integer
#
# Indexes
#
#  index_token_transfers_on_from_id         (from_id)
#  index_token_transfers_on_item_id         (item_id)
#  index_token_transfers_on_to_id           (to_id)
#  index_token_transfers_on_transaction_id  (transaction_id)
#
require "test_helper"

class TokenTransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @token_transfer = token_transfers(:one)
  end

  test "should get index" do
    get token_transfers_url, as: :json
    assert_response :success
  end

  test "should create token_transfer" do
    assert_difference('TokenTransfer.count') do
      post token_transfers_url, params: { token_transfer: { from_id: @token_transfer.from_id, item_id: @token_transfer.item_id, to_id: @token_transfer.to_id, transaction_id: @token_transfer.transaction_id } }, as: :json
    end

    assert_response 201
  end

  test "should show token_transfer" do
    get token_transfer_url(@token_transfer), as: :json
    assert_response :success
  end

  test "should update token_transfer" do
    patch token_transfer_url(@token_transfer), params: { token_transfer: { from_id: @token_transfer.from_id, item_id: @token_transfer.item_id, to_id: @token_transfer.to_id, transaction_id: @token_transfer.transaction_id } }, as: :json
    assert_response 200
  end

  test "should destroy token_transfer" do
    assert_difference('TokenTransfer.count', -1) do
      delete token_transfer_url(@token_transfer), as: :json
    end

    assert_response 204
  end
end
