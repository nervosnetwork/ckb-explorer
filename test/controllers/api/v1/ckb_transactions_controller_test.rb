require "test_helper"

module Api
  module V1
    class CkbTransactionsControllerTest < ActionDispatch::IntegrationTest
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
        error_object = Api::V1::Exceptions::WrongContentTypeError.new
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
        error_object = Api::V1::Exceptions::WrongAcceptError.new
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

      test "should contain right keys in the serialized object when call show" do
        prepare_node_data(8)
        ckb_transaction = CkbTransaction.last

        valid_get api_v1_ckb_transaction_url(ckb_transaction.tx_hash)

        response_tx_transaction = json["data"]
        assert_equal %w(block_number transaction_hash block_timestamp transaction_fee version display_inputs display_outputs is_cellbase income witnesses cell_deps header_deps).sort, response_tx_transaction["attributes"].keys.sort
      end

      test "returned income should be null" do
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
        error_object = Api::V1::Exceptions::WrongContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_ckb_transactions_url, headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when  call index and Accept is wrong" do
        get api_v1_ckb_transactions_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when  call index and Accept is wrong" do
        error_object = Api::V1::Exceptions::WrongAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_ckb_transactions_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should get serialized objects" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, block: block)

        ckb_transactions = CkbTransaction.recent.limit(ENV["HOMEPAGE_TRANSACTIONS_RECORDS_COUNT"].to_i)

        valid_get api_v1_ckb_transactions_url

        assert_equal CkbTransactionSerializer.new(ckb_transactions).serialized_json, response.body
      end

      test "serialized objects should in reverse order of timestamp" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, block: block)

        valid_get api_v1_ckb_transactions_url

        first_ckb_transaction = json["data"].first
        last_ckb_transaction = json["data"].last

        assert_operator first_ckb_transaction.dig("attributes", "block_timestamp"), :>, last_ckb_transaction.dig("attributes", "block_timestamp")
      end

      test "should contain right keys in the serialized object" do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 15, block: block)

        valid_get api_v1_ckb_transactions_url

        response_ckb_transaction = json["data"].first
        assert_equal %w(block_number transaction_hash block_timestamp transaction_fee version display_inputs display_outputs is_cellbase income witnesses cell_deps header_deps).sort, response_ckb_transaction["attributes"].keys.sort
      end

      test "should return the corresponding number of ckb transactions " do
        block = create(:block, :with_block_hash)
        create_list(:ckb_transaction, 30, block: block)

        valid_get api_v1_ckb_transactions_url

        ckb_transactions = CkbTransaction.order(block_timestamp: :desc).limit(ENV["HOMEPAGE_TRANSACTIONS_RECORDS_COUNT"].to_i)
        response_ckb_transaction = CkbTransactionSerializer.new(ckb_transactions).serialized_json
        assert_equal response_ckb_transaction, response.body
        assert_equal 15, json["data"].size
      end

      test "should return empty array when there is no ckb_transactions" do
        ckb_transactions = CkbTransaction.order(block_timestamp: :desc).limit(15)

        valid_get api_v1_ckb_transactions_url

        response_ckb_transaction = CkbTransactionSerializer.new(ckb_transactions).serialized_json

        assert_equal [], json["data"]
        assert_equal response_ckb_transaction, response.body
      end
    end
  end
end
