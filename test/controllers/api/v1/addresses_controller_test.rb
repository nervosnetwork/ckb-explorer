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
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
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
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
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
        address.query_address = address.address_hash

        valid_get api_v1_address_url(address.address_hash)

        assert_equal AddressSerializer.new(address).serialized_json, response.body
      end

      test "should return corresponding data with given lock hash" do
        address = create(:address, :with_lock_script)

        valid_get api_v1_address_url(address.lock_hash)

        assert_equal LockHashSerializer.new(address).serialized_json, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        address = create(:address, :with_lock_script)

        valid_get api_v1_address_url(address.address_hash)

        assert_equal %w(address_hash balance transactions_count lock_script dao_deposit interest lock_info is_special live_cells_count mined_blocks_count average_deposit_time udt_accounts dao_compensation balance_occupied).sort, json["data"]["attributes"].keys.sort
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

      test "should support full address query when short address's lock script exists" do
        address = create(:address, :with_lock_script, address_hash: "ckb1qyqt8xaupvm8837nv3gtc9x0ekkj64vud3jqfwyw5v")
        query_key = "ckb1qjda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xw3vumhs9nvu786dj9p0q5elx66t24n3kxgj53qks"
        address.query_address = query_key
        valid_get api_v1_address_url(query_key)

        assert_equal AddressSerializer.new(address).serialized_json, response.body
      end

      test "should support short address query when full address's lock script exists" do
        address = create(:address, :with_lock_script, address_hash: "ckb1qjda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xw3vumhs9nvu786dj9p0q5elx66t24n3kxgj53qks")
        query_key = "ckb1qyqt8xaupvm8837nv3gtc9x0ekkj64vud3jqfwyw5v"
        address.query_address = query_key
        valid_get api_v1_address_url(query_key)

        assert_equal AddressSerializer.new(address).serialized_json, response.body
      end

      test "should return published udt accounts with given address hash" do
        address = create(:address, :with_lock_script)
        udt_account = create(:udt_account, published: true, address: address)
        address.query_address = address.address_hash
        valid_get api_v1_address_url(address.address_hash)

        assert_equal [
          {
            "symbol" => udt_account.symbol,
            "decimal" => udt_account.decimal.to_s,
            "amount" => udt_account.amount.to_s,
            "type_hash" => udt_account.type_hash,
            "udt_icon_file" => udt_account.udt_icon_file,
            "udt_type" => udt_account.udt_type,
            "display_name" => nil,
            "uan" => nil
          }
        ], json.dig("data", "attributes", "udt_accounts")
      end

      test "should not return unpublished udt accounts with given address hash" do
        address = create(:address, :with_lock_script)
        create(:udt_account, address: address)
        address.query_address = address.address_hash

        valid_get api_v1_address_url(address.address_hash)

        assert_empty json.dig("data", "attributes", "udt_accounts")
      end

      test "should return balance occupied" do
        address = create(:address, :with_lock_script, address_hash: "ckb1qyq0hcfpff4h8w8zvy44uurvlgdrr09tefwqx266dl")

        valid_get api_v1_address_url(address.address_hash)
        assert_equal "0", json.dig("data", "attributes", "balance_occupied")
      end

      test "should return nrc 721 udt accounts with given address hash" do
        type_script = create :type_script
        address = create(:address, :with_lock_script)
        factory_cell = create(:nrc_factory_cell,
                              verified: true,
                              name: "NrcFactoryToken",
                              symbol: "NFT",
                              base_token_uri: "https://dev.nrc.com",
                              code_hash: type_script.code_hash,
                              hash_type: type_script.hash_type,
                              args: type_script.args)
        udt = create(:udt, udt_type: "nrc_721_token", nrc_factory_cell_id: factory_cell.id, full_name: "OldName", symbol: "ON")
        udt_account = create(:udt_account, published: true, address: address, udt_id: udt.id, nft_token_id: "1a2b3c", udt_type: "nrc_721_token")
        address.query_address = address.address_hash
        valid_get api_v1_address_url(address.address_hash)

        assert_equal [
          {
            "symbol" => factory_cell.symbol,
            "amount" => udt_account.nft_token_id.to_s,
            "type_hash" => nil,
            "udt_icon_file" => "https://dev.nrc.com/1a2b3c",
            "udt_type" => udt_account.udt_type,
            "collection" => { "type_hash" => type_script.script_hash }
          }
        ], json.dig("data", "attributes", "udt_accounts")
      end
    end
  end
end
