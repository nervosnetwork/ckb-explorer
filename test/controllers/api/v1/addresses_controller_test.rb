require "test_helper"

module Api
  module V1
    class AddressesControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        address = create(:address, :with_lock_script)

        valid_get api_v1_address_url(address.address_hash)

        assert_response :success
      end

      test "should set right content type when call show" do
        address = create(:address, :with_lock_script)

        valid_get api_v1_address_url(address.address_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        address = create(:address, :with_lock_script)

        get api_v1_address_url(address.address_hash), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        address = create(:address, :with_lock_script)
        error_object = Api::V1::Exceptions::WrongContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_address_url(address.address_hash), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        address = create(:address, :with_lock_script)

        get api_v1_address_url(address.address_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        address = create(:address, :with_lock_script)
        error_object = Api::V1::Exceptions::WrongAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_address_url(address.address_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a address hash" do
        error_object = Api::V1::Exceptions::AddressHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return corresponding data with given address hash" do
        address = create(:address, :with_lock_script)
        presented_address = AddressPresenter.new(address)

        valid_get api_v1_address_url(address.address_hash)

        assert_equal AddressSerializer.new(presented_address).serialized_json, response.body
      end

      test "should return corresponding data with given lock hash" do
        address = create(:address, :with_lock_script)

        valid_get api_v1_address_url(address.lock_hash)

        assert_equal LockHashSerializer.new(address).serialized_json, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        address = create(:address, :with_lock_script)

        valid_get api_v1_address_url(address.address_hash)

        assert_equal %w(address_hash balance transactions_count lock_script pending_reward_blocks_count dao_deposit interest lock_info is_special live_cells_count).sort, json["data"]["attributes"].keys.sort
      end

      test "should return NullAddress when address no found by id" do
        ENV["CKB_NET_MODE"] = "testnet"
        address = NullAddress.new("ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83")
        response_json = AddressSerializer.new(address).serialized_json

        valid_get api_v1_address_url("ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83")

        assert_equal response_json, response.body
        ENV["CKB_NET_MODE"] = "mainnet"
      end

      test "should return special address when query address is special" do
        address = create(:address, :with_lock_script, address_hash: "ckb1qyq0hcfpff4h8w8zvy44uurvlgdrr09tefwqx266dl")

        valid_get api_v1_address_url(address.address_hash)
        assert_equal Settings.special_addresses[address.address_hash], json.dig("data", "attributes", "special_address")
      end

      test "should not return special address when query address is not special" do
        address = create(:address, :with_lock_script, address_hash: "ckb1qyqdmeuqrsrnm7e5vnrmruzmsp4m9wacf6vsxasryq")

        valid_get api_v1_address_url(address.address_hash)
        assert_nil json.dig("data", "attributes", "special_address")
      end
    end
  end
end
