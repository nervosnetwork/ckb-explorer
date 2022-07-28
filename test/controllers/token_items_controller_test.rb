# == Schema Information
#
# Table name: token_items
#
#  id             :bigint           not null, primary key
#  collection_id  :integer
#  token_id       :string
#  name           :string
#  icon_url       :string
#  owner_id       :integer
#  metadata_url   :string
#  cell_id        :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  type_script_id :integer
#
# Indexes
#
#  index_token_items_on_cell_id                     (cell_id)
#  index_token_items_on_collection_id_and_token_id  (collection_id,token_id) UNIQUE
#  index_token_items_on_owner_id                    (owner_id)
#
require "test_helper"

class TokenItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @token_item = token_items(:one)
  end

  test "should get index" do
    get token_items_url, as: :json
    assert_response :success
  end

  test "should create token_item" do
    assert_difference('TokenItem.count') do
      post token_items_url, params: { token_item: { cell_id: @token_item.cell_id, collection_id: @token_item.collection_id, icon_url: @token_item.icon_url, metadata_url: @token_item.metadata_url, name: @token_item.name, owner_id: @token_item.owner_id, token_id: @token_item.token_id } }, as: :json
    end

    assert_response 201
  end

  test "should show token_item" do
    get token_item_url(@token_item), as: :json
    assert_response :success
  end

  test "should update token_item" do
    patch token_item_url(@token_item), params: { token_item: { cell_id: @token_item.cell_id, collection_id: @token_item.collection_id, icon_url: @token_item.icon_url, metadata_url: @token_item.metadata_url, name: @token_item.name, owner_id: @token_item.owner_id, token_id: @token_item.token_id } }, as: :json
    assert_response 200
  end

  test "should destroy token_item" do
    assert_difference('TokenItem.count', -1) do
      delete token_item_url(@token_item), as: :json
    end

    assert_response 204
  end
end
