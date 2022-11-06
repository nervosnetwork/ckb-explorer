require "test_helper"

module Api
  module V1
    class CkbTransactionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
      end

      test "should get success code when call show" do
        ckb_transaction = create(:ckb_transaction)

        valid_get api_v1_ckb_transaction_url(ckb_transaction.tx_hash)

        assert_response :success
      end

      test "should set right content type when call show" do
        ckb_transaction = create(:ckb_transaction)

        valid_get api_v1_ckb_transaction_url(ckb_transaction.tx_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        ckb_transaction = create(:ckb_transaction)

        get api_v1_ckb_transaction_url(ckb_transaction.tx_hash), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        ckb_transaction = create(:ckb_transaction)
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_ckb_transaction_url(ckb_transaction.tx_hash), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        ckb_transaction = create(:ckb_transaction)

        get api_v1_ckb_transaction_url(ckb_transaction.tx_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        ckb_transaction = create(:ckb_transaction)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_ckb_transaction_url(ckb_transaction.tx_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a hex start with 0x" do
        error_object = Api::V1::Exceptions::CkbTransactionTxHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_ckb_transaction_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return error object when id is a hex start with 0x but it's length is wrong" do
        error_object = Api::V1::Exceptions::CkbTransactionTxHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_ckb_transaction_url("0x9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::CkbTransactionNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_ckb_transaction_url("0x3b138b3126d10ec000417b68bc715f17e86293d6cdbcb3fd8a628ad4a0b756f6")

        assert_equal response_json, response.body
      end

      test "should return corresponding ckb transaction with given transaction hash" do
        ckb_transaction = create(:ckb_transaction)

        valid_get api_v1_ckb_transaction_url(ckb_transaction.tx_hash)

        assert_equal CkbTransactionSerializer.new(ckb_transaction).serialized_json, response.body
      end

      test "should return pool tx when tx is in the pool" do
        tx = create(:pool_transaction_entry)

        valid_get api_v1_ckb_transaction_url(tx.tx_hash)

        expected_response = CkbTransactionSerializer.new(tx).serialized_json
        assert_equal expected_response, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        create(:table_record_count, :block_counter)
        create(:table_record_count, :ckb_transactions_counter)
        prepare_node_data(8)
        ckb_transaction = CkbTransaction.last

        valid_get api_v1_ckb_transaction_url(ckb_transaction.tx_hash)

        response_tx_transaction = json["data"]
        assert_equal %w(block_number transaction_hash block_timestamp transaction_fee bytes version display_inputs display_outputs is_cellbase income witnesses cell_deps header_deps tx_status detailed_message).sort, response_tx_transaction["attributes"].keys.sort
      end

      test "returned income should be null" do
        create(:table_record_count, :block_counter)
        create(:table_record_count, :ckb_transactions_counter)
        prepare_node_data(8)
        ckb_transaction = CkbTransaction.last

        valid_get api_v1_ckb_transaction_url(ckb_transaction.tx_hash)

        assert_nil json["data"].dig("attributes", "income")
      end

      test "should return all display_inputs" do
        block = create(:block, :with_block_hash)
        ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: block)

        valid_get api_v1_ckb_transaction_url(ckb_transaction.tx_hash)

        assert_equal 15, json["data"].dig("attributes", "display_inputs").count
        assert_equal [true], json["data"].dig("attributes", "display_inputs").map { |input| input.key?("from_cellbase") }.uniq
      end

      test "should return all display_outputs" do
        block = create(:block, :with_block_hash)
        ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: block)

        valid_get api_v1_ckb_transaction_url(ckb_transaction.tx_hash)

        assert_equal 15, json["data"].dig("attributes", "display_outputs").count
        assert_equal [false], json["data"].dig("attributes", "display_outputs").map { |input| input.key?("from_cellbase") }.uniq
      end

      test "should get success code when call index" do
        valid_get api_v1_ckb_transactions_url

        assert_response :success
      end

      test "should set right content type when call index" do
        valid_get api_v1_ckb_transactions_url

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when call index and Content-Type is wrong" do
        get api_v1_ckb_transactions_url, headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when call index and Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_ckb_transactions_url, headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when  call index and Accept is wrong" do
        get api_v1_ckb_transactions_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when  call index and Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_ckb_transactions_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should get serialized objects" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, block: block)

        ckb_transactions = CkbTransaction.recent.limit(ENV["HOMEPAGE_TRANSACTIONS_RECORDS_COUNT"].to_i)

        valid_get api_v1_ckb_transactions_url

        assert_equal CkbTransactionListSerializer.new(ckb_transactions).serialized_json, response.body
      end

      test "serialized objects should in reverse order of timestamp" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, block: block)

        valid_get api_v1_ckb_transactions_url

        first_ckb_transaction = json["data"].first
        last_ckb_transaction = json["data"].last

        assert_operator first_ckb_transaction.dig("attributes", "block_timestamp"), :>=, last_ckb_transaction.dig("attributes", "block_timestamp")
      end

      test "should contain right keys in the serialized object" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, block: block)

        valid_get api_v1_ckb_transactions_url

        response_ckb_transaction = json["data"].first
        assert_equal %w(block_number transaction_hash block_timestamp capacity_involved live_cell_changes).sort, response_ckb_transaction["attributes"].keys.sort
      end

      test "should return the corresponding number of ckb transactions " do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 30, block: block)

        valid_get api_v1_ckb_transactions_url

        ckb_transactions = CkbTransaction.recent.limit(ENV["HOMEPAGE_TRANSACTIONS_RECORDS_COUNT"].to_i)
        response_ckb_transaction = CkbTransactionListSerializer.new(ckb_transactions).serialized_json
        assert_equal response_ckb_transaction, response.body
        assert_equal 15, json["data"].size
      end

      test "should return empty array when there is no ckb_transactions" do
        ckb_transactions = CkbTransaction.recent.limit(15)

        valid_get api_v1_ckb_transactions_url

        response_ckb_transaction = CkbTransactionListSerializer.new(ckb_transactions).serialized_json

        assert_equal [], json["data"]
        assert_equal response_ckb_transaction, response.body
      end

      test "should return error object when page param is invalid" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, block: block)
        error_object = Api::V1::Exceptions::PageParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_ckb_transactions_url, params: { page: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page size param is invalid" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, block: block)
        error_object = Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_ckb_transactions_url, params: { page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page and page size param are invalid" do
        errors = []
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, block: block)
        errors << Api::V1::Exceptions::PageParamError.new
        errors << Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new(errors, message: errors.first.title).serialized_json

        valid_get api_v1_ckb_transactions_url, params: { page: "bbb", page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return 15 records when page and page_size are not set" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 20, block: block)

        valid_get api_v1_ckb_transactions_url

        assert_equal 15, json["data"].size
      end

      test "should return corresponding page's records when page is set and page_size is not set" do
        page = 2
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 20, block: block)
        ckb_transactions = CkbTransaction.recent.limit(ENV["HOMEPAGE_TRANSACTIONS_RECORDS_COUNT"].to_i)

        valid_get api_v1_ckb_transactions_url, params: { page: page }

        response_ckb_transactions = CkbTransactionListSerializer.new(ckb_transactions, {}).serialized_json

        assert_equal response_ckb_transactions, response.body
        assert_equal 15, json["data"].size
      end

      test "should return the corresponding number of ckb_transactions when page is not set and page_size is set" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 20, block: block)

        valid_get api_v1_ckb_transactions_url, params: { page_size: 12 }

        ckb_transactions = CkbTransaction.recent.limit(ENV["HOMEPAGE_TRANSACTIONS_RECORDS_COUNT"].to_i)
        response_ckb_transactions = CkbTransactionListSerializer.new(ckb_transactions, {}).serialized_json

        assert_equal response_ckb_transactions, response.body
        assert_equal [false], CkbTransaction.where(id: json["data"].map { |tx| tx.dig("id") }).pluck(:is_cellbase).uniq
        assert_equal 15, json["data"].size
      end

      test "should return the corresponding transactions when page and page_size are set" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, block: block)
        create(:table_record_count, :block_counter, count: Block.count)
        create(:table_record_count, :ckb_transactions_counter, count: CkbTransaction.count)
        page = 2
        page_size = 5
        ckb_transactions = CkbTransaction.recent.page(page).per(page_size)

        valid_get api_v1_ckb_transactions_url, params: { page: page, page_size: page_size }

        records_counter = RecordCounters::Transactions.new
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: page, page_size: page_size, records_counter: records_counter).call
        response_ckb_transactions = CkbTransactionListSerializer.new(ckb_transactions, options).serialized_json
        assert_equal response_ckb_transactions, response.body
      end

      test "should return corresponding ckb transactions with given address hash" do
        page = 1
        page_size = 10
        address = create(:address, :with_transactions)
        ckb_transactions = address.ckb_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_post api_v1_query_ckb_transactions_url, params: {address: address.address_hash}

        records_counter = RecordCounters::AddressTransactions.new(address)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: page, page_size: page_size, records_counter: records_counter).call

        assert_equal CkbTransactionsSerializer.new(ckb_transactions, options.merge(params: { previews: true, address: address })).serialized_json, response.body
      end
    end
  end
end
