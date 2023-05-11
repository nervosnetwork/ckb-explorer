require "test_helper"

module Api
  module V1
    class SuggestQueriesControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        block = create(:block)
        valid_get api_v1_suggest_queries_url, params: { q: block.number }

        assert_response :success
      end

      test "should set right content type when call show" do
        valid_get api_v1_suggest_queries_url("0x3b238b3326d10ec000417b68bc715f17e86293d6cdbcb3fd8a628ad4a0b756f6")

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_suggest_queries_url, params: { q: "12" }, headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_suggest_queries_url, params: { q: "12" }, headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_suggest_queries_url, params: { q: "12" }, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_suggest_queries_url, params: { q: "12" }, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should response with error object when query key is neither integer nor hex or address" do
        error_object = Api::V1::Exceptions::SuggestQueryKeyInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: "0x3b238b3326d10ec000417b6&^&bc715f17e86293d6cdbcb3fd8a628ad4a0b756f6" }

        assert_equal response_json, response.body
      end

      test "should response with error object when query key is not a hex start with 0x and not a address" do
        error_object = Api::V1::Exceptions::SuggestQueryKeyInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: "3b238b3326d10ec000417b68bc715f17e86293d6cdbcb3fd8a628ad4a0b756f6" }

        assert_equal response_json, response.body
      end

      test "should return error object when query key is a hex start with 0x but the length is wrong" do
        error_object = Api::V1::Exceptions::SuggestQueryKeyInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: "0x3b238b3326d10ec0004" }

        assert_equal response_json, response.body
      end

      test "should return error object when query key is not a address" do
        error_object = Api::V1::Exceptions::SuggestQueryKeyInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: "ckc2q9gry5zgwayze0rtl8g0m8lgtx0cj35hmajzz2r9e6rtnt" }

        assert_equal response_json, response.body
      end

      test "should return a block when query key is a exist block height" do
        Block.delete_all
        block = create(:block)
        response_json = BlockSerializer.new(block).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: block.number }
        assert_equal response_json, response.body
      end

      test "should return a block when query key is a exist block hash" do
        Block.delete_all
        block = create(:block)
        response_json = BlockSerializer.new(block).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: block.block_hash }

        assert_equal response_json, response.body
      end

      test "should return a ckb transaction when query key is a exist ckb transaction hash" do
        ckb_transaction = create(:ckb_transaction)
        response_json = CkbTransactionSerializer.new(ckb_transaction).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: ckb_transaction.tx_hash }

        assert_equal response_json, response.body
      end

      test "should return address when query key is a exist address hash" do
        address = create(:address, :with_lock_script)
        address.query_address = address.address_hash
        response_json = AddressSerializer.new(address).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: address.address_hash }

        assert_equal response_json, response.body
      end

      test "should return error object when no records found by a integer query key" do
        error_object = Api::V1::Exceptions::BlockNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: 1 }

        assert_equal response_json, response.body
      end

      test "should return error object when no records found by a hex query key" do
        error_object = Api::V1::Exceptions::SuggestQueryResultNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: "0x4b238b3326d10ec000417b68bc715f17e86293d6cdbcb3fd8a628ad4a0b756f6" }

        assert_equal response_json, response.body
      end

      test "should return error object when no records found by a address query key" do
        ENV["CKB_NET_MODE"] = "testnet"
        address = NullAddress.new("ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83")
        response_json = AddressSerializer.new(address).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: "ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83" }

        assert_equal response_json, response.body
        ENV["CKB_NET_MODE"] = "mainnet"
      end

      test "should support full address query when short address's lock script exists" do
        address = create(:address, :with_lock_script, address_hash: "ckb1qyqt8xaupvm8837nv3gtc9x0ekkj64vud3jqfwyw5v")
        query_key = "ckb1qjda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xw3vumhs9nvu786dj9p0q5elx66t24n3kxgj53qks"
        address.query_address = query_key
        valid_get api_v1_suggest_queries_url, params: { q: query_key }

        assert_equal AddressSerializer.new(address).serialized_json, response.body
      end

      test "should support short address query when full address's lock script exists" do
        address = create(:address, :with_lock_script, address_hash: "ckb1qjda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xw3vumhs9nvu786dj9p0q5elx66t24n3kxgj53qks")
        query_key = "ckb1qyqt8xaupvm8837nv3gtc9x0ekkj64vud3jqfwyw5v"
        address.query_address = query_key
        valid_get api_v1_address_url(query_key)

        assert_equal AddressSerializer.new(address).serialized_json, response.body
      end

      test "should return a udt when query key is a exist udt type hash" do
        udt = create(:udt, published: true)
        response_json = UdtSerializer.new(udt).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: udt.type_hash }

        assert_equal response_json, response.body
      end

      test "should return error object when target udt is not published" do
        udt = create(:udt)
        error_object = Api::V1::Exceptions::SuggestQueryResultNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_suggest_queries_url, params: { q: udt.type_hash }

        assert_equal response_json, response.body
      end
    end
  end
end
