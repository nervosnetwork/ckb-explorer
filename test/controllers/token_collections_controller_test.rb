# == Schema Information
#
# Table name: token_collections
#
#  id            :bigint           not null, primary key
#  standard      :string
#  name          :string
#  description   :text
#  creator_id    :integer
#  icon_url      :string
#  items_count   :integer
#  holders_count :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  symbol        :string
#  cell_id       :integer
#  verified      :boolean          default(FALSE)
#
require "test_helper"

class TokenCollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @token_collection = token_collections(:one)
  end

  test "should get index" do
    get token_collections_url, as: :json
    assert_response :success
  end

  test "should create token_collection" do
    assert_difference('TokenCollection.count') do
      post token_collections_url, params: { token_collection: { creator_id: @token_collection.creator_id, description: @token_collection.description, holders_count: @token_collection.holders_count, icon_url: @token_collection.icon_url, items_count: @token_collection.items_count, name: @token_collection.name, standard: @token_collection.standard } }, as: :json
    end

    assert_response 201
  end

  test "should show token_collection" do
    get token_collection_url(@token_collection), as: :json
    assert_response :success
  end

  test "should update token_collection" do
    patch token_collection_url(@token_collection), params: { token_collection: { creator_id: @token_collection.creator_id, description: @token_collection.description, holders_count: @token_collection.holders_count, icon_url: @token_collection.icon_url, items_count: @token_collection.items_count, name: @token_collection.name, standard: @token_collection.standard } }, as: :json
    assert_response 200
  end

  test "should destroy token_collection" do
    assert_difference('TokenCollection.count', -1) do
      delete token_collection_url(@token_collection), as: :json
    end

    assert_response 204
  end
end
