require "test_helper"

module Api
  module V1
    class ContractTransactionsControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call show" do
        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
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

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: ckb_transactions, page:, page_size:).call

        assert_equal CkbTransactionsSerializer.new(ckb_transactions, options.merge({ params: { previews: true } })).serialized_json, response.body
      end

      test "should contain right keys in the serialized transaction when call show" do
        address = create(:address)
        fake_dao_deposit_transaction(5, address)
        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)

        response_tx_transaction = json["data"].first

        assert_equal %w(block_number block_timestamp display_inputs display_inputs_count
                        display_outputs display_outputs_count income is_cellbase transaction_hash
                        created_at create_timestamp is_rgb_transaction rgb_txid).sort, response_tx_transaction["attributes"].keys.sort
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
        address = create(:address)
        fake_dao_deposit_transaction(30, address)
        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)

        assert_equal 10, json["data"].size
      end

      test "should return corresponding page's records when page is set and page_size is not set" do
        address = create(:address)
        fake_dao_deposit_transaction(30, address)
        page = 2
        page_size = 10
        dao_contract = DaoContract.default_contract
        contract_ckb_transactions = dao_contract.ckb_transactions.recent.page(page).per(page_size)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page: }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: contract_ckb_transactions, page:, page_size:).call
        response_transaction = CkbTransactionsSerializer.new(contract_ckb_transactions, options).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return corresponding records when page is not set and page_size is set" do
        address = create(:address)
        fake_dao_deposit_transaction(15, address)
        page = 1
        page_size = 12
        dao_contract = DaoContract.default_contract
        contract_ckb_transactions = dao_contract.ckb_transactions.recent.page(page).per(page_size)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page_size: }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: contract_ckb_transactions, page:, page_size:).call
        response_transaction = CkbTransactionsSerializer.new(contract_ckb_transactions, options).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions when page and page_size are set" do
        address = create(:address)
        fake_dao_deposit_transaction(30, address)
        page = 2
        page_size = 5
        dao_contract = DaoContract.default_contract
        contract_ckb_transactions = dao_contract.ckb_transactions.recent.page(page).per(page_size)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page:, page_size: }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: contract_ckb_transactions, page:, page_size:).call
        response_transaction = CkbTransactionsSerializer.new(contract_ckb_transactions, options).serialized_json

        assert_equal response_transaction, response.body
      end

      test "should return empty array when there is no record under the contract" do
        page = 2
        page_size = 5
        dao_contract = DaoContract.default_contract
        contract_ckb_transactions = dao_contract.ckb_transactions.recent.page(page).per(page_size)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME), params: { page:, page_size: }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: contract_ckb_transactions, page:, page_size:).call
        response_transaction = CkbTransactionsSerializer.new(contract_ckb_transactions, options).serialized_json

        assert_equal [], json["data"]
        assert_equal response_transaction, response.body
      end

      test "should return meta that contained total in response body" do
        address = create(:address)
        fake_dao_deposit_transaction(3, address)

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME)

        assert_equal 3, json.dig("meta", "total")
      end

      test "should return the corresponding transactions when tx_hash are set" do
        page = 1
        page_size = 10
        address = create(:address)
        fake_dao_deposit_transaction(15, address)

        tx_hash = address.ckb_dao_transactions.pick(:tx_hash)
        contract_ckb_transactions = address.ckb_dao_transactions.where(tx_hash:).page(page).per(page_size).fast_page

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME),
                  params: { page:, page_size:, tx_hash: }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: contract_ckb_transactions, page:,
                                                           page_size:).call
        response_transaction = CkbTransactionsSerializer.new(contract_ckb_transactions,
                                                             options.merge(params: { previews: true })).serialized_json

        assert_equal 1, json["data"].size
        assert_equal response_transaction, response.body
      end

      test "should return the corresponding transactions when address_hash are set" do
        page = 1
        page_size = 10
        address = create(:address)
        fake_dao_deposit_transaction(15, address)

        contract_ckb_transactions = address.ckb_dao_transactions.joins(:account_books).
          where(account_books: { address_id: address.id }).
          order("ckb_transactions.block_timestamp desc nulls last, ckb_transactions.id desc").page(page).per(page_size).fast_page

        valid_get api_v1_contract_transaction_url(DaoContract::CONTRACT_NAME),
                  params: { page:, page_size:, address_hash: address.address_hash }

        options = FastJsonapi::PaginationMetaGenerator.new(request:, records: contract_ckb_transactions, page:,
                                                           page_size:).call
        response_transaction = CkbTransactionsSerializer.new(contract_ckb_transactions,
                                                             options.merge(params: { previews: true })).serialized_json

        assert_equal response_transaction, response.body
      end
    end
  end
end
