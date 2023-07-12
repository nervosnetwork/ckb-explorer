require "test_helper"

module Api
  module V2
    module NFT
      class HoldersControllerTest < ActionDispatch::IntegrationTest
        test "should get success code when call index" do
          collection = create(:token_collection, :with_items)

          get api_v2_nft_collection_holders_url(collection_id: collection.id)

          assert_response :success
        end

        test "should return error object when id is not a hex start with 0x" do
          error_object = Api::V2::Exceptions::TokenCollectionNotFoundError.new
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          get api_v2_nft_collection_holders_url(collection_id: "9034fwefwef")

          assert_equal response_json, response.body
        end

        test "should return error object when id is a hex start with 0x but it's length is wrong" do
          error_object = Api::V2::Exceptions::TokenCollectionNotFoundError.new
          response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

          get api_v2_nft_collection_holders_url(collection_id: "0x9034fwefwef")

          assert_equal response_json, response.body
        end

        test "should get success code when id is script_hash" do
          collection = create(:token_collection, :with_items)

          get api_v2_nft_collection_holders_url(collection_id: collection.type_script.script_hash)

          assert_response :success
        end

        test "should return the corresponding data when address_hash are set" do
          collection = create(:token_collection, :with_items)
          item = collection.items.sample

          get api_v2_nft_collection_holders_url(collection_id: collection.id),
              params: { address_hash: item.owner.address_hash }

          assert_equal 1, json["data"].size
          assert_equal item.owner.address_hash, json["data"].keys[0]
        end

        test "should sorted by quantity asc when sort param is quantity" do
          collection = create(:token_collection, items_count: 6, holders_count: 2)

          owner = create(:address)
          4.times do |i|
            create(:token_item, token_id: i, collection: collection, owner: owner)
          end

          owner = create(:address)
          3.times do |i|
            create(:token_item, token_id: i + 4, collection: collection, owner: owner)
          end

          get api_v2_nft_collection_holders_url(collection_id: collection.id),
              params: { sort: "quantity" }

          response_json = {
            data: collection.items.joins(:owner).
              order("count_all asc").group(:address_hash).count }.as_json

          assert_equal response_json, json
        end
      end
    end
  end
end
