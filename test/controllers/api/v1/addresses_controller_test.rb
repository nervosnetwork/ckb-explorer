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

        get api_v1_address_url(address.address_hash),
            headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        address = create(:address, :with_lock_script)
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        get api_v1_address_url(address.address_hash),
            headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        address = create(:address, :with_lock_script)

        get api_v1_address_url(address.address_hash),
            headers: { "Content-Type": "application/vnd.api+json",
                       "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        address = create(:address, :with_lock_script)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        get api_v1_address_url(address.address_hash),
            headers: { "Content-Type": "application/vnd.api+json",
                       "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a address hash" do
        error_object = Api::V1::Exceptions::AddressNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_address_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return corresponding data with given address hash" do
        page = 1
        page_size = 100
        address = create(:address, :with_lock_script)
        address.query_address = address.address_hash

        valid_get api_v1_address_url(address.address_hash)

        options = FastJsonapi::PaginationMetaGenerator.new(
          request:, records: [address], page:, page_size:, total_count: 1,
        ).call

        assert_equal AddressSerializer.new([address], options).serialized_json,
                     response.body
      end

      test "should return corresponding data with given lock hash" do
        address = create(:address, :with_lock_script)

        valid_get api_v1_address_url(address.lock_hash)

        assert_equal LockHashSerializer.new(address).serialized_json,
                     response.body
      end

      test "should contain right keys in the serialized object when call show" do
        address = create(:address, :with_lock_script)

        valid_get api_v1_address_url(address.address_hash)

        assert_equal %w(address_hash balance transactions_count lock_script dao_deposit
                        interest lock_info is_special live_cells_count mined_blocks_count
                        average_deposit_time udt_accounts dao_compensation balance_occupied
                        bitcoin_address_hash).sort,
                     json["data"][0]["attributes"].keys.sort
      end

      test "should return special address when query address is special" do
        address = create(:address, :with_lock_script,
                         address_hash: "ckb1qyq0hcfpff4h8w8zvy44uurvlgdrr09tefwqx266dl")

        valid_get api_v1_address_url(address.address_hash)
        assert_equal Settings.special_addresses[address.address_hash],
                     json.dig("data", 0, "attributes", "special_address")
      end

      test "should not return special address when query address is not special" do
        address = create(:address, :with_lock_script,
                         address_hash: "ckb1qyqdmeuqrsrnm7e5vnrmruzmsp4m9wacf6vsxasryq")

        valid_get api_v1_address_url(address.address_hash)
        assert_nil json.dig("data", 0, "attributes", "special_address")
      end

      test "should support full address query when short address's lock script exists" do
        address = create(:address, :with_lock_script,
                         address_hash: "ckb1qyqt8xaupvm8837nv3gtc9x0ekkj64vud3jqfwyw5v")
        query_key = "ckb1qjda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xw3vumhs9nvu786dj9p0q5elx66t24n3kxgj53qks"
        address.query_address = query_key
        valid_get api_v1_address_url(query_key)

        options = FastJsonapi::PaginationMetaGenerator.new(
          request:, records: [address], page: 1, page_size: 100, total_count: 1,
        ).call

        assert_equal AddressSerializer.new([address], options).serialized_json,
                     response.body
      end

      test "should support short address query when full address's lock script exists" do
        address = create(:address, :with_lock_script,
                         address_hash: "ckb1qjda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xw3vumhs9nvu786dj9p0q5elx66t24n3kxgj53qks")
        query_key = "ckb1qyqt8xaupvm8837nv3gtc9x0ekkj64vud3jqfwyw5v"
        address.query_address = query_key
        valid_get api_v1_address_url(query_key)

        options = FastJsonapi::PaginationMetaGenerator.new(
          request:, records: [address], page: 1, page_size: 100, total_count: 1,
        ).call

        assert_equal AddressSerializer.new([address], options).serialized_json,
                     response.body
      end

      test "should return published udt accounts with given address hash" do
        address = create(:address, :with_lock_script)
        udt_account = create(:udt_account, published: true, address:)
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
            "udt_type_script" => nil,
          },
        ], json.dig("data", 0, "attributes", "udt_accounts")
      end

      test "should not return unpublished udt accounts with given address hash" do
        address = create(:address, :with_lock_script)
        create(:udt_account, address:)
        address.query_address = address.address_hash

        valid_get api_v1_address_url(address.address_hash)

        assert_empty json.dig("data", 0, "attributes", "udt_accounts")
      end

      test "should return balance occupied" do
        address = create(:address, :with_lock_script,
                         address_hash: "ckb1qyq0hcfpff4h8w8zvy44uurvlgdrr09tefwqx266dl")

        valid_get api_v1_address_url(address.address_hash)
        assert_equal "0", json.dig("data", 0, "attributes", "balance_occupied")
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
        udt = create(:udt, udt_type: "nrc_721_token", nrc_factory_cell_id: factory_cell.id, full_name: "OldName",
                           symbol: "ON")
        udt_account = create(:udt_account, published: true, address:, udt_id: udt.id, nft_token_id: "1a2b3c",
                                           udt_type: "nrc_721_token")
        address.query_address = address.address_hash
        valid_get api_v1_address_url(address.address_hash)

        assert_equal [
          {
            "symbol" => factory_cell.symbol,
            "amount" => udt_account.nft_token_id.to_s,
            "type_hash" => nil,
            "udt_icon_file" => "https://dev.nrc.com/1a2b3c",
            "udt_type" => udt_account.udt_type,
            "collection" => { "type_hash" => type_script.script_hash },
            "udt_type_script" => nil,
          },
        ], json.dig("data", 0, "attributes", "udt_accounts")
      end

      test "should return spore cell udt accounts with given address hash" do
        output = create :cell_output, :with_full_transaction,
                        cell_type: "spore_cell"
        cell_data = create :cell_datum, cell_output: output
        cluster_type = create :type_script
        tc = create :token_collection, type_script: cluster_type,
                                       standard: "spore"
        create :token_item, collection_id: tc.id, cell_id: output.id
        address = create(:address, :with_lock_script)
        udt = create(:udt, udt_type: "spore_cell", full_name: "SporeTest")
        udt_account = create(:udt_account, full_name: udt.full_name, published: true, address:, udt_id: udt.id, nft_token_id: "123456",
                                           udt_type: "spore_cell", type_hash: output.type_script.script_hash)
        address.query_address = address.address_hash
        valid_get api_v1_address_url(address.address_hash)
        assert_equal [
          {
            "symbol" => "SporeTest",
            "amount" => udt_account.nft_token_id.to_s,
            "type_hash" => output.type_script.script_hash,
            "udt_icon_file" => cell_data.hex_data,
            "udt_type" => udt_account.udt_type,
            "collection" => { "type_hash" => cluster_type.script_hash },
            "udt_type_script" => nil,
          },
        ], json.dig("data", 0, "attributes", "udt_accounts")
      end

      test "should return omiga inscription udt accounts with given address hash" do
        udt = create(:udt, :omiga_inscription, full_name: "CKB Fist Inscription",
                                               symbol: "CKBI", decimal: 8)
        info = udt.omiga_inscription_info
        address = create(:address, :with_lock_script)
        udt_account = create(:udt_account, symbol: udt.symbol, full_name: udt.full_name, decimal: udt.decimal, published: true, address:, udt_id: udt.id,
                                           udt_type: "omiga_inscription", type_hash: udt.type_hash, amount: info.mint_limit)
        address.query_address = address.address_hash
        valid_get api_v1_address_url(address.address_hash)
        assert_equal [
          {
            "symbol" => udt.symbol,
            "decimal" => udt.decimal.to_s,
            "amount" => udt_account.amount.to_s,
            "type_hash" => udt.type_hash,
            "udt_type" => udt_account.udt_type,
            "udt_amount" => udt_account.udt.total_amount.to_s,
            "expected_supply" => info.expected_supply.to_s,
            "mint_status" => info.mint_status,
            "udt_type_script" => udt.type_script&.transform_keys(&:to_s),
          },
        ], json.dig("data", 0, "attributes", "udt_accounts")
      end
    end
  end
end
