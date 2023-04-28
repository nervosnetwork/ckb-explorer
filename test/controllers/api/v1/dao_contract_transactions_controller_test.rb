require "test_helper"
module Api
  module V1
    class DaoContractTransactionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        create(:table_record_count, :block_counter)
        create(:table_record_count, :ckb_transactions_counter)
        CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
      end

      test "should set right content type when call index" do
        ckb_transaction = create(:ckb_transaction)

        valid_get api_v1_dao_contract_transaction_url(ckb_transaction.tx_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        ckb_transaction = create(:ckb_transaction)

        get api_v1_dao_contract_transaction_url(ckb_transaction.tx_hash), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        ckb_transaction = create(:ckb_transaction)

        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_dao_contract_transaction_url(ckb_transaction.tx_hash), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        ckb_transaction = create(:ckb_transaction)

        get api_v1_dao_contract_transaction_url(ckb_transaction.tx_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        ckb_transaction = create(:ckb_transaction)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_dao_contract_transaction_url(ckb_transaction.tx_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a hex start with 0x" do
        error_object = Api::V1::Exceptions::CkbTransactionTxHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_dao_contract_transaction_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return error object when id is a hex start with 0x but it's length is wrong" do
        error_object = Api::V1::Exceptions::CkbTransactionTxHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_dao_contract_transaction_url("0x9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::CkbTransactionNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_dao_contract_transaction_url("0x3b138b3126d10ec000417b68bc715f17e86293d6cdbcb3fd8a628ad4a0b756f6")

        assert_equal response_json, response.body
      end

      test "should return corresponding ckb transaction with given transaction hash and the tx's input is dao cell" do
        ckb_transaction = create(:ckb_transaction)
        create(:cell_output, ckb_transaction: ckb_transaction,
                             cell_index: 0,
                             tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",
                             consumed_by: ckb_transaction,
                             status: "dead",
                             block: ckb_transaction.block,
                             capacity: 10**8 * 1000,
                             cell_type: "nervos_dao_deposit")

        valid_get api_v1_dao_contract_transaction_url(ckb_transaction.tx_hash)

        assert_equal CkbTransactionSerializer.new(ckb_transaction).serialized_json, response.body
      end

      test "should return corresponding ckb transaction with given transaction hash and the tx's output is dao cell" do
        ckb_transaction = create(:ckb_transaction)
        create(:cell_output, ckb_transaction: ckb_transaction,
                             cell_index: 0,
                             tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",
                             consumed_by: ckb_transaction,
                             status: "dead",
                             block: ckb_transaction.block,
                             capacity: 10**8 * 1000,
                             cell_type: "nervos_dao_deposit")
        valid_get api_v1_dao_contract_transaction_url(ckb_transaction.tx_hash)

        assert_equal CkbTransactionSerializer.new(ckb_transaction).serialized_json, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        prepare_node_data(8)
        ckb_transaction = create(:ckb_transaction)
        create(:cell_output, ckb_transaction: ckb_transaction,
                             cell_index: 0,
                             tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",
                             consumed_by: ckb_transaction,
                             status: "dead",
                             block: ckb_transaction.block,
                             capacity: 10**8 * 1000,
                             cell_type: "nervos_dao_withdrawing")

        valid_get api_v1_dao_contract_transaction_url(ckb_transaction.tx_hash)

        response_tx_transaction = json["data"]
        assert_equal %w(block_number transaction_hash block_timestamp transaction_fee version bytes display_inputs display_outputs is_cellbase income witnesses cell_deps header_deps tx_status detailed_message largest_tx largest_tx_in_epoch cycles max_cycles_in_epoch max_cycles).sort, response_tx_transaction["attributes"].keys.sort
      end

      test "should return error object when given tx hash corresponds to a normal transaction" do
        ckb_transaction = create(:ckb_transaction)
        error_object = Api::V1::Exceptions::CkbTransactionNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_dao_contract_transaction_url(ckb_transaction.tx_hash)

        assert_equal response_json, response.body
      end
    end
  end
end
