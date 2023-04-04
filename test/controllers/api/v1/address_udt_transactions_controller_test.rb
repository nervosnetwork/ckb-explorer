require "test_helper"

module Api
  module V1
    class AddressUdtTransactionsControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call index" do
        address = create(:address)
        valid_get api_v1_address_udt_transaction_url(address.address_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        address = create(:address)
        get api_v1_address_udt_transaction_url(address.address_hash), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json
        address = create(:address)

        get api_v1_address_udt_transaction_url(address.address_hash), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        address = create(:address)
        get api_v1_address_udt_transaction_url(address.address_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json
        address = create(:address)

        get api_v1_address_udt_transaction_url(address.address_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a address hash" do
        error_object = Api::V1::Exceptions::AddressHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json
        udt = create(:udt, published: true)
        valid_get api_v1_address_udt_transaction_url("9034fwefwef", type_hash: udt.type_hash)

        assert_equal response_json, response.body
      end

      test "should return error object when type_hash is invalid" do
        error_object = Api::V1::Exceptions::TypeHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json
        address = create(:address)
        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: "fwefwefw")

        assert_equal response_json, response.body
      end

      test "should return error object when type_hash is empty" do
        error_object = Api::V1::Exceptions::TypeHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json
        address = create(:address, :with_udt_transactions)

        valid_get api_v1_address_udt_transaction_url(address.address_hash)

        assert_equal response_json, response.body
      end

      test "should return corresponding ckb transactions with given address hash" do
        page = 1
        page_size = 10
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, udt: udt)
        ckb_udt_transactions = address.ckb_udt_transactions(udt.id).recent.page(page).per(page_size)

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash)

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_udt_transactions, page: page, page_size: page_size).call

        assert_equal CkbTransactionsSerializer.new(ckb_udt_transactions, options.merge(params: { previews: true })).serialized_json, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, udt: udt)

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash)

        response_tx_transaction = json["data"].first

        assert_equal %w(block_number block_timestamp display_inputs display_inputs_count display_outputs display_outputs_count income is_cellbase transaction_hash).sort, response_tx_transaction["attributes"].keys.sort
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::AddressNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json
        udt = create(:udt, published: true)

        valid_get api_v1_address_udt_transaction_url("ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83", type_hash: udt.type_hash)

        assert_equal response_json, response.body
      end

      test "should return error object when no records found by type_hash" do
        error_object = Api::V1::Exceptions::UdtNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json
        udt = create(:udt)
        address = create(:address)

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash)

        assert_equal response_json, response.body
      end

      test "should return error object when page param is invalid" do
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, udt: udt)
        error_object = Api::V1::Exceptions::PageParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash), params: { page: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page size param is invalid" do
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, udt: udt)
        error_object = Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash), params: { page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page and page size param are invalid" do
        errors = []
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, udt: udt)
        errors << Api::V1::Exceptions::PageParamError.new
        errors << Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new(errors, message: errors.first.title).serialized_json

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash), params: { page: "bbb", page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return 10 records when page and page_size are not set" do
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, transactions_count: 15, udt: udt)

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash)

        assert_equal 10, json["data"].size
      end

      test "should return corresponding page's records when page is set and page_size is not set" do
        page = 2
        page_size = 10
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, transactions_count: 30, udt: udt)

        address_udt_transactions = address.ckb_udt_transactions(udt.id).recent.recent.page(page).per(page_size)

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash), params: { page: page }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_udt_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionsSerializer.new(address_udt_transactions, options.merge(params: { previews: true })).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions under the address when page is not set and page_size is set" do
        page = 1
        page_size = 12
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, transactions_count: 15, udt: udt)
        address_udt_transactions = address.ckb_udt_transactions(udt.id).recent.page(page).per(page_size)

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash), params: { page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_udt_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionsSerializer.new(address_udt_transactions, options.merge(params: { previews: true })).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions when page and page_size are set" do
        page = 2
        page_size = 5
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, transactions_count: 30, udt: udt)
        address_udt_transactions = address.ckb_udt_transactions(udt.id).order("block_timestamp desc nulls last, id desc").page(page).per(page_size)

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash), params: { page: page, page_size: page_size }
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_udt_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionsSerializer.new(address_udt_transactions, options.merge(params: { previews: true })).serialized_json

        assert_equal response_transaction, response.body
      end

      test "should return empty array when there is no record under the address" do
        page = 20
        page_size = 5
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, udt: udt)

        address_udt_transactions = address.ckb_udt_transactions(udt.id).recent.page(page).per(page_size)

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash), params: { page: page, page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_udt_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionsSerializer.new(address_udt_transactions, options.merge(params: { previews: true })).serialized_json

        assert_equal [], json["data"]
        assert_equal response_transaction, response.body
      end

      test "should return meta that contained total in response body" do
        udt = create(:udt, published: true)
        address = create(:address, :with_udt_transactions, transactions_count: 3, udt: udt)

        valid_get api_v1_address_udt_transaction_url(address.address_hash, type_hash: udt.type_hash)

        assert_equal 6, json.dig("meta", "total")
      end
    end
  end
end
