require "test_helper"

module Api
  module V1
    class AddressPendingTransactionsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        address = create(:address, :with_pending_transactions)

        valid_get api_v1_address_pending_transaction_url(address.address_hash)

        assert_response :success
      end

      test "should set right content type when call show" do
        address = create(:address, :with_pending_transactions)

        valid_get api_v1_address_pending_transaction_url(address.address_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        address = create(:address, :with_pending_transactions)

        get api_v1_address_pending_transaction_url(address.address_hash),
            headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        address = create(:address, :with_pending_transactions)
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        get api_v1_address_pending_transaction_url(address.address_hash),
            headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        address = create(:address, :with_pending_transactions)

        get api_v1_address_pending_transaction_url(address.address_hash),
            headers: {
              "Content-Type": "application/vnd.api+json",
              "Accept": "application/json"
            }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        address = create(:address, :with_pending_transactions)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new(
          [error_object],
          message: error_object.title
        ).serialized_json

        get api_v1_address_pending_transaction_url(address.address_hash),
            headers: {
              "Content-Type": "application/vnd.api+json",
              "Accept": "application/json"
            }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a address hash" do
        error_object = Api::V1::Exceptions::AddressHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_address_pending_transaction_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return corresponding ckb transactions with given address hash" do
        page = 1
        page_size = 10
        address = create(:address, :with_pending_transactions)
        ckb_transactions = address.ckb_transactions.order(id: :desc).page(page).per(page_size)

        valid_get api_v1_address_pending_transaction_url(address.address_hash)

        options = FastJsonapi::PaginationMetaGenerator.new(
          request: request,
          records: ckb_transactions,
          page: page,
          page_size: page_size
        ).call

        assert_equal CkbTransactionsSerializer.new(
          ckb_transactions,
          options.merge(
            params: {
              previews: true,
              address: address
            }
          )
        ).serialized_json, response.body
      end

      test "should return corresponding ckb transactions with given lock hash" do
        page = 1
        page_size = 10
        address = create(:address, :with_pending_transactions)
        ckb_transactions = address.ckb_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_pending_transaction_url(address.lock_hash)

        options = FastJsonapi::PaginationMetaGenerator.new(
          request: request,
          records: ckb_transactions,
          page: page,
          page_size: page_size
        ).call

        assert_equal CkbTransactionsSerializer.new(
          ckb_transactions,
          options.merge(
            params: {
              previews: true,
              address: address
            }
          )
        ).serialized_json, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        address = create(:address, :with_pending_transactions)

        valid_get api_v1_address_pending_transaction_url(address.address_hash)

        response_tx_transaction = json["data"].first

        assert_equal %w(
          block_number
          block_timestamp
          display_inputs
          display_inputs_count
          display_outputs
          display_outputs_count
          income
          is_cellbase
          transaction_hash
          created_at
          create_timestamp
        ).sort, response_tx_transaction["attributes"].keys.sort
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::AddressNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_address_pending_transaction_url("ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83")

        assert_equal response_json, response.body
      end

      test "should return error object when page param is invalid" do
        address = create(:address, :with_pending_transactions)
        error_object = Api::V1::Exceptions::PageParamError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_address_pending_transaction_url(address.address_hash),
                  params: { page: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page size param is invalid" do
        address = create(:address, :with_pending_transactions)
        error_object = Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new([error_object],
                                                   message: error_object.title).serialized_json

        valid_get api_v1_address_pending_transaction_url(address.address_hash),
                  params: { page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page and page size param are invalid" do
        errors = []
        address = create(:address, :with_pending_transactions)
        errors << Api::V1::Exceptions::PageParamError.new
        errors << Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new(errors,
                                                   message: errors.first.title).serialized_json

        valid_get api_v1_address_pending_transaction_url(address.address_hash),
                  params: { page: "bbb", page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return 10 records when page and page_size are not set" do
        address = create(:address, :with_pending_transactions, transactions_count: 15)

        valid_get api_v1_address_pending_transaction_url(address.address_hash)

        assert_equal 10, json["data"].size
      end

      test "should return corresponding page's records when page is set and page_size is not set" do
        page = 2
        page_size = 10
        address = create(:address, :with_pending_transactions, transactions_count: 30)
        address_ckb_transactions = address.custom_ckb_transactions.
          order("id desc NULLS LAST").
          page(page).
          per(page_size)
        valid_get api_v1_address_pending_transaction_url(address.address_hash), params: { page: page }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request,
                                                           records: address_ckb_transactions,
                                                           page: page,
                                                           page_size: page_size).call
        response_transaction = CkbTransactionsSerializer.new(
          address_ckb_transactions, options.merge(params: {
            previews: true,
            address: address })
        ).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions under the address when page is not set and page_size is set" do
        page = 1
        page_size = 12
        address = create(:address, :with_pending_transactions, transactions_count: 15)
        address_ckb_transactions = address.ckb_transactions.order("id desc NULLS LAST").page(page).per(page_size)

        valid_get api_v1_address_pending_transaction_url(address.address_hash),
                  params: { page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request,
                                                           records: address_ckb_transactions,
                                                           page: page,
                                                           page_size: page_size).call
        response_transaction = CkbTransactionsSerializer.new(
          address_ckb_transactions, options.merge(params: {
            previews: true,
            address: address
          })
        ).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions when page and page_size are set" do
        page = 2
        page_size = 5
        address = create(:address, :with_pending_transactions, transactions_count: 30)
        address_ckb_transactions = address.ckb_transactions.order("id desc NULLS LAST").page(page).per(page_size)

        valid_get api_v1_address_pending_transaction_url(address.address_hash),
                  params: { page: page, page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request,
                                                           records: address_ckb_transactions,
                                                           page: page,
                                                           page_size: page_size).call
        response_transaction = CkbTransactionsSerializer.new(
          address_ckb_transactions, options.merge(params: {
            previews: true,
            address: address
          })
        ).serialized_json

        assert_equal response_transaction, response.body
      end

      test "should return empty array when there is no record under the address" do
        page = 2
        page_size = 5
        address = create(:address, :with_pending_transactions)
        address_ckb_transactions = address.ckb_transactions.order("id desc NULLS LAST").page(page).per(page_size)

        valid_get api_v1_address_pending_transaction_url(address.address_hash),
                  params: { page: page, page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request,
                                                           records: address_ckb_transactions,
                                                           page: page,
                                                           page_size: page_size).call
        response_transaction = CkbTransactionsSerializer.new(
          address_ckb_transactions, options.merge(params: {
            previews: true,
            address: address
          })
        ).serialized_json

        assert_equal [], json["data"]
        assert_equal response_transaction, response.body
      end

      test "should return meta that contained total in response body" do
        address = create(:address, :with_pending_transactions, transactions_count: 3)

        valid_get api_v1_address_pending_transaction_url(address.address_hash)

        assert_equal 3, json.dig("meta", "total")
      end

      test "should return up to ten display_inputs" do
        address = create(:address)
        block = create(:block, :with_block_hash)
        create(:pending_transaction,
               :with_multiple_inputs_and_outputs, block: block, contained_address_ids: [address.id])

        valid_get api_v1_address_pending_transaction_url(address.address_hash)

        assert_equal 10,
                     json["data"].first.dig("attributes",
                                            "display_inputs").count
        assert_equal [true], json["data"].first.dig("attributes", "display_inputs").map { |input|
          input.key?("from_cellbase")
        }.uniq
      end

      test "should return up to ten display_outputs" do
        address = create(:address)
        block = create(:block, :with_block_hash)
        create(:pending_transaction,
               :with_multiple_inputs_and_outputs, block: block, contained_address_ids: [address.id])

        valid_get api_v1_address_pending_transaction_url(address.address_hash)

        assert_equal 10,
                     json["data"].first.dig("attributes",
                                            "display_outputs").count
        assert_equal [false], json["data"].first.dig("attributes", "display_outputs").map { |input|
          input.key?("from_cellbase")
        }.uniq
      end
    end
  end
end
