require "test_helper"

module Api
  module V1
    class AddressDaoTransactionsControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call index" do
        address = create(:address)
        valid_get api_v1_address_dao_transaction_url(address.address_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        address = create(:address)
        get api_v1_address_dao_transaction_url(address.address_hash), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json
        address = create(:address)

        get api_v1_address_dao_transaction_url(address.address_hash), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        address = create(:address)
        get api_v1_address_dao_transaction_url(address.address_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json
        address = create(:address)

        get api_v1_address_dao_transaction_url(address.address_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a address hash" do
        error_object = Api::V1::Exceptions::AddressHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_dao_transaction_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return corresponding ckb transactions with given address hash" do
        page = 1
        page_size = 10
        address = create(:address, :with_transactions)
        fake_dao_deposit_transaction(3, address)
        ckb_dao_transactions = address.ckb_dao_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_dao_transaction_url(address.address_hash)

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_dao_transactions, page: page, page_size: page_size).call

        assert_equal CkbTransactionSerializer.new(ckb_dao_transactions, options.merge(params: {previews: true})).serialized_json, response.body
      end

      test "should return corresponding ckb transactions with given lock hash" do
        page = 1
        page_size = 10
        address = create(:address, :with_transactions)
        fake_dao_deposit_transaction(3, address)
        ckb_dao_transactions = address.ckb_dao_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_dao_transaction_url(address.lock_hash)

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_dao_transactions, page: page, page_size: page_size).call

        assert_equal CkbTransactionSerializer.new(ckb_dao_transactions, options.merge(params: {previews: true})).serialized_json, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        address = create(:address, :with_transactions)
        fake_dao_deposit_transaction(3, address)

        valid_get api_v1_address_dao_transaction_url(address.address_hash)

        response_tx_transaction = json["data"].first

        assert_equal %w(block_number transaction_hash block_timestamp transaction_fee version display_inputs display_outputs is_cellbase income witnesses cell_deps header_deps).sort, response_tx_transaction["attributes"].keys.sort
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::AddressNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_dao_transaction_url("ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83")

        assert_equal response_json, response.body
      end

      test "should return error object when page param is invalid" do
        address = create(:address, :with_transactions)
        error_object = Api::V1::Exceptions::PageParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_dao_transaction_url(address.address_hash), params: { page: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page size param is invalid" do
        address = create(:address, :with_transactions)
        error_object = Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_dao_transaction_url(address.address_hash), params: { page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page and page size param are invalid" do
        errors = []
        address = create(:address, :with_transactions)
        errors << Api::V1::Exceptions::PageParamError.new
        errors << Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new(errors, message: errors.first.title).serialized_json

        valid_get api_v1_address_dao_transaction_url(address.address_hash), params: { page: "bbb", page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return 10 records when page and page_size are not set" do
        address = create(:address, :with_transactions, transactions_count: 15)
        fake_dao_deposit_transaction(15, address)

        valid_get api_v1_address_dao_transaction_url(address.address_hash)

        assert_equal 10, json["data"].size
      end

      test "should return corresponding page's records when page is set and page_size is not set" do
        page = 2
        page_size = 10
        address = create(:address, :with_transactions, transactions_count: 30)
        fake_dao_deposit_transaction(30, address)
        address_dao_transactions = address.ckb_dao_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_dao_transaction_url(address.address_hash), params: { page: page }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_dao_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionSerializer.new(address_dao_transactions, options.merge(params: {previews: true})).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions under the address when page is not set and page_size is set" do
        page = 1
        page_size = 12
        address = create(:address, :with_transactions, transactions_count: 15)
        fake_dao_deposit_transaction(15, address)
        address_dao_transactions = address.ckb_dao_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_dao_transaction_url(address.address_hash), params: { page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_dao_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionSerializer.new(address_dao_transactions, options.merge(params: {previews: true})).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions when page and page_size are set" do
        page = 2
        page_size = 5
        address = create(:address, :with_transactions, transactions_count: 30)
        fake_dao_deposit_transaction(30, address)
        address_dao_transactions = address.ckb_dao_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_dao_transaction_url(address.address_hash), params: { page: page, page_size: page_size }
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_dao_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionSerializer.new(address_dao_transactions, options.merge(params: {previews: true})).serialized_json

        assert_equal response_transaction, response.body
      end

      test "should return empty array when there is no record under the address" do
        page = 2
        page_size = 5
        address = create(:address, :with_transactions)
        fake_dao_deposit_transaction(3, address)
        address_dao_transactions = address.ckb_dao_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_dao_transaction_url(address.address_hash), params: { page: page, page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_dao_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionSerializer.new(address_dao_transactions, options.merge(params: {previews: true})).serialized_json

        assert_equal [], json["data"]
        assert_equal response_transaction, response.body
      end

      test "should return pagination links in response body" do
        page = 2
        page_size = 3
        address = create(:address, :with_transactions, transactions_count: 30)
        fake_dao_deposit_transaction(30, address)

        links = {
          self: "#{api_v1_address_dao_transaction_url(address.address_hash)}?page=2&page_size=3",
          first: "#{api_v1_address_dao_transaction_url(address.address_hash)}?page_size=3",
          prev: "#{api_v1_address_dao_transaction_url(address.address_hash)}?page_size=3",
          next: "#{api_v1_address_dao_transaction_url(address.address_hash)}?page=3&page_size=3",
          last: "#{api_v1_address_dao_transaction_url(address.address_hash)}?page=10&page_size=3"
        }

        valid_get api_v1_address_dao_transaction_url(address.address_hash), params: { page: page, page_size: page_size }

        assert_equal links.stringify_keys.sort, json["links"].sort
      end

      test "should return meta that contained total in response body" do
        address = create(:address, :with_transactions, transactions_count: 3)
        fake_dao_deposit_transaction(3, address)

        valid_get api_v1_address_dao_transaction_url(address.address_hash)

        assert_equal 3, json.dig("meta", "total")
      end

      test "should return pagination links that only contain self in response bod when there is no blocks" do
        address = create(:address, :with_transactions)

        links = {
          self: "#{api_v1_address_dao_transaction_url(address.address_hash)}?page_size=10"
        }

        valid_get api_v1_address_dao_transaction_url(address.address_hash)
        assert_equal links.stringify_keys.sort, json["links"].sort
      end

      private

      def fake_dao_deposit_transaction(dao_cell_count, address)
        block = create(:block, :with_block_hash)
        dao_cell_count.times do |number|
          ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x#{SecureRandom.hex(32)}", block: block, address: address)
          ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x#{SecureRandom.hex(32)}", block: block, address: address)
          generated_by = number % 2 == 0 ? ckb_transaction2 : ckb_transaction1
          create(:cell_output, ckb_transaction: generated_by, cell_index: number, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: generated_by, block: block, capacity: 10**8 * 1000, cell_type: "nervos_dao_deposit", address: address)
        end
      end
    end
  end
end
