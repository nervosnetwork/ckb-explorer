require "test_helper"

module Api
  module V1
    class ContractTransactionsControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call index" do
        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::WrongContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::WrongAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return corresponding ckb transactions with given contract name" do
        page = 1
        page_size = 10
        dao_contract = DaoContract.default_contract
        ckb_transactions = dao_contract.ckb_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: page, page_size: page_size).call

        assert_equal CkbTransactionSerializer.new(ckb_transactions, options.merge({ params: { previews: true } })).serialized_json, response.body
      end

      test "should contain right keys in the serialized transaction when call show" do
        fake_dao_deposit_transaction(5)
        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)

        response_tx_transaction = json["data"].first

        assert_equal %w(block_number transaction_hash block_timestamp transaction_fee version display_inputs display_outputs is_cellbase income witnesses cell_deps header_deps).sort, response_tx_transaction["attributes"].keys.sort
      end

      test "should return error object when no records found by give contract name" do
        error_object = Api::V1::Exceptions::ContractNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_contract_transaction_url("Ethereum")

        assert_equal response_json, response.body
      end

      test "should return error object when page param is invalid" do
        error_object = Api::V1::Exceptions::PageParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page size param is invalid" do
        error_object = Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page and page size param are invalid" do
        errors = []
        errors << Api::V1::Exceptions::PageParamError.new
        errors << Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new(errors, message: errors.first.title).serialized_json

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page: "bbb", page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return 10 records when page and page_size are not set" do
        fake_dao_deposit_transaction(30)
        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)

        assert_equal 10, json["data"].size
      end

      test "should return corresponding page's records when page is set and page_size is not set" do
        fake_dao_deposit_transaction(30)
        page = 2
        page_size = 10
        dao_contract = DaoContract.default_contract
        contract_ckb_transactions = dao_contract.ckb_transactions.recent.page(page).per(page_size)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page: page }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: contract_ckb_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionSerializer.new(contract_ckb_transactions, options).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return corresponding records when page is not set and page_size is set" do
        fake_dao_deposit_transaction(15)
        page = 1
        page_size = 12
        dao_contract = DaoContract.default_contract
        contract_ckb_transactions = dao_contract.ckb_transactions.recent.page(page).per(page_size)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: contract_ckb_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionSerializer.new(contract_ckb_transactions, options).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions when page and page_size are set" do
        fake_dao_deposit_transaction(30)
        page = 2
        page_size = 5
        dao_contract = DaoContract.default_contract
        contract_ckb_transactions = dao_contract.ckb_transactions.recent.page(page).per(page_size)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page: page, page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: contract_ckb_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionSerializer.new(contract_ckb_transactions, options).serialized_json

        assert_equal response_transaction, response.body
      end

      test "should return empty array when there is no record under the contract" do
        page = 2
        page_size = 5
        dao_contract = DaoContract.default_contract
        contract_ckb_transactions = dao_contract.ckb_transactions.recent.page(page).per(page_size)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page: page, page_size: page_size }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: contract_ckb_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionSerializer.new(contract_ckb_transactions, options).serialized_json

        assert_equal [], json["data"]
        assert_equal response_transaction, response.body
      end

      test "should return pagination links in response body" do
        fake_dao_deposit_transaction(30)
        page = 2
        page_size = 3

        links = {
          self: "#{api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)}?page=2&page_size=3",
          first: "#{api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)}?page_size=3",
          prev: "#{api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)}?page_size=3",
          next: "#{api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)}?page=3&page_size=3",
          last: "#{api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)}?page=10&page_size=3"
        }

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page: page, page_size: page_size }

        assert_equal links.stringify_keys.sort, json["links"].sort
      end

      test "should return meta that contained total in response body" do
        fake_dao_deposit_transaction(3)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)

        assert_equal 3, json.dig("meta", "total")
      end

      test "should return pagination links that only contain self in response bod when there is no transactions" do
        links = {
          self: "#{api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)}?page_size=10"
        }

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)
        assert_equal links.stringify_keys.sort, json["links"].sort
      end

      private

      def fake_dao_deposit_transaction(dao_cell_count)
        block = create(:block, :with_block_hash)
        dao_cell_count.times do |number|
          ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x#{SecureRandom.hex(32)}", block: block)
          ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x#{SecureRandom.hex(32)}", block: block)
          generated_by = number % 2 == 0 ? ckb_transaction2 : ckb_transaction1
          create(:cell_output, ckb_transaction: generated_by, cell_index: number, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: generated_by, block: block, capacity: 10**8 * 1000, cell_type: "nervos_dao_deposit")
        end
      end
    end
  end
end

