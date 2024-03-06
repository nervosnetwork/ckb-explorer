require "test_helper"

module Api
  module V1
    class BlockTransactionsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        block = create(:block, :with_ckb_transactions)

        valid_get api_v1_block_transaction_url(block.block_hash)

        assert_response :success
      end

      test "should set right content type when call show" do
        block = create(:block, :with_ckb_transactions)

        valid_get api_v1_block_transaction_url(block.block_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        block = create(:block, :with_ckb_transactions)

        get api_v1_block_transaction_url(block.block_hash), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        block = create(:block, :with_ckb_transactions)
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_block_transaction_url(block.block_hash), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        block = create(:block, :with_ckb_transactions)

        get api_v1_block_transaction_url(block.block_hash),
            headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        block = create(:block, :with_ckb_transactions)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_block_transaction_url(block.block_hash),
            headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a hex start with 0x" do
        error_object = Api::V1::Exceptions::BlockHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_block_transaction_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return error object when id is a hex start with 0x but it's length is wrong" do
        error_object = Api::V1::Exceptions::BlockHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_block_transaction_url("0x9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return corresponding ckb transactions with given block hash" do
        page = 1
        page_size = 10
        block = create(:block, :with_ckb_transactions)

        valid_get api_v1_block_transaction_url(block.block_hash)

        ckb_transactions = block.ckb_transactions.order(:id).page(page).per(page_size)
        records_counter = RecordCounters::BlockTransactions.new(block)
        options = FastJsonapi::PaginationMetaGenerator.new(
          request:, records: ckb_transactions, page:,
          page_size:, records_counter:
        ).call

        assert_equal CkbTransactionsSerializer.new(
          ckb_transactions,
          options.merge(params: { previews: true }),
        ).serialized_json, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        block = create(:block, :with_ckb_transactions)

        valid_get api_v1_block_transaction_url(block.block_hash)

        response_tx_transaction = json["data"].first
        assert_equal %w(
          block_number block_timestamp display_inputs
          display_inputs_count display_outputs display_outputs_count
          income is_cellbase transaction_hash rgb_transaction
          created_at create_timestamp
        ).sort, response_tx_transaction["attributes"].keys.sort
      end

      test "returned income should be null" do
        block = create(:block, :with_ckb_transactions)

        valid_get api_v1_block_transaction_url(block.block_hash)

        assert_nil json["data"].map { |transaction| transaction.dig("attributes", "income") }.uniq.first
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::BlockTransactionsNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_block_transaction_url("0x3b138b3126d10ec000417b68bc715f17e86293d6cdbcb3fd8a628ad4a0b756f6")

        assert_equal response_json, response.body
      end

      test "should return error object when address_hash param is invalid" do
        block = create(:block, :with_ckb_transactions)
        error_object = Api::V1::Exceptions::AddressHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_block_transaction_url(block.block_hash), params: { address_hash: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when tx_hash param is invalid" do
        block = create(:block, :with_ckb_transactions)
        error_object = Api::V1::Exceptions::CkbTransactionTxHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_block_transaction_url(block.block_hash), params: { tx_hash: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page param is invalid" do
        block = create(:block, :with_ckb_transactions)
        error_object = Api::V1::Exceptions::PageParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_block_transaction_url(block.block_hash), params: { page: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page size param is invalid" do
        block = create(:block, :with_ckb_transactions)
        error_object = Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_block_transaction_url(block.block_hash), params: { page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page and page size param are invalid" do
        errors = []
        block = create(:block, :with_ckb_transactions)
        errors << Api::V1::Exceptions::PageParamError.new
        errors << Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new(errors, message: errors.first.title).serialized_json

        valid_get api_v1_block_transaction_url(block.block_hash), params: { page: "bbb", page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return 10 records when page and page_size are not set" do
        block = create(:block, :with_ckb_transactions, transactions_count: 15)

        valid_get api_v1_block_transaction_url(block.block_hash)

        assert_equal 10, json["data"].size
      end

      test "should return corresponding page's records when page is set and page_size is not set" do
        page = 2
        page_size = 10
        block = create(:block, :with_ckb_transactions, transactions_count: 30)
        ckb_transactions = block.ckb_transactions.order(:id).page(page).per(page_size).fast_page

        valid_get api_v1_block_transaction_url(block.block_hash), params: { page: }

        records_counter = RecordCounters::BlockTransactions.new(block)
        options = FastJsonapi::PaginationMetaGenerator.new(
          request:, records: ckb_transactions,
          page:, page_size:,
          records_counter:
        ).call
        response_transaction = CkbTransactionsSerializer.new(
          ckb_transactions,
          options.merge(params: { previews: true }),
        ).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return corresponding records when page is not set and page_size is set" do
        page = 1
        page_size = 12
        block = create(:block, :with_ckb_transactions, transactions_count: 15)
        ckb_transactions = block.ckb_transactions.order(:id).page(page).per(page_size).fast_page

        valid_get api_v1_block_transaction_url(block.block_hash), params: { page_size: }

        records_counter = RecordCounters::BlockTransactions.new(block)
        options = FastJsonapi::PaginationMetaGenerator.new(
          request:, records: ckb_transactions,
          page:, page_size:,
          records_counter:
        ).call
        response_transaction = CkbTransactionsSerializer.new(
          ckb_transactions,
          options.merge(params: { previews: true }),
        ).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions when page and page_size are set" do
        CkbTransaction.delete_all
        page = 2
        page_size = 5
        block = create(:block, :with_ckb_transactions, transactions_count: 30)
        ckb_transactions = block.ckb_transactions.order(:id).page(page).per(page_size).fast_page

        valid_get api_v1_block_transaction_url(block.block_hash), params: { page:, page_size: }

        records_counter = RecordCounters::BlockTransactions.new(block)
        options = FastJsonapi::PaginationMetaGenerator.new(
          request:, records: ckb_transactions,
          page:, page_size:,
          records_counter:
        ).call
        response_transaction = CkbTransactionsSerializer.new(
          ckb_transactions,
          options.merge(params: { previews: true }),
        ).serialized_json

        assert_equal response_transaction, response.body
      end

      test "should return empty array when there is no record under the block" do
        page = 2
        page_size = 5
        block = create(:block)
        ckb_transactions = block.ckb_transactions.order(:id).page(page).per(page_size).fast_page

        valid_get api_v1_block_transaction_url(block.block_hash), params: { page:, page_size: }

        records_counter = RecordCounters::BlockTransactions.new(block.ckb_transactions)
        options = FastJsonapi::PaginationMetaGenerator.new(
          request:, records: ckb_transactions,
          page:, page_size:,
          records_counter:
        ).call
        response_transaction = CkbTransactionsSerializer.new(
          ckb_transactions,
          options.merge(params: { previews: true }),
        ).serialized_json

        assert_equal [], json["data"]
        assert_equal response_transaction, response.body
      end

      test "should return meta that contained total in response body" do
        block = create(:block, :with_ckb_transactions, transactions_count: 3)

        valid_get api_v1_block_transaction_url(block.block_hash)

        assert_equal 3, json.dig("meta", "total")
      end

      test "should return up to ten display_inputs" do
        block = create(:block, :with_block_hash)
        create(:ckb_transaction, :with_multiple_inputs_and_outputs, block:)

        valid_get api_v1_block_transaction_url(block.block_hash)

        assert_equal 10, json["data"].first.dig("attributes", "display_inputs").count
        assert_equal [true], json["data"].first.dig("attributes", "display_inputs").map { |input|
                               input.key?("from_cellbase")
                             }.uniq
      end

      test "should return up to ten display_outputs" do
        block = create(:block, :with_block_hash)
        create(:ckb_transaction, :with_multiple_inputs_and_outputs, block:)

        valid_get api_v1_block_transaction_url(block.block_hash)

        assert_equal 10, json["data"].first.dig("attributes", "display_outputs").count
        assert_equal [false], json["data"].first.dig("attributes", "display_outputs").map { |input|
                                input.key?("from_cellbase")
                              }.uniq
      end

      test "should return the corresponding transactions when tx_hash are set" do
        page = 1
        page_size = 10
        block = create(:block, :with_ckb_transactions, transactions_count: 15)
        tx_hash = CkbTransaction.where(block:).pick(:tx_hash)
        ckb_transactions = block.ckb_transactions.where(tx_hash:).order(:id)
        records_counter = RecordCounters::BlockTransactions.new(ckb_transactions)
        ckb_transactions = ckb_transactions.page(page).per(page_size).fast_page

        valid_get api_v1_block_transaction_url(block.block_hash),
                  params: { page:, page_size:, tx_hash: }

        options = FastJsonapi::PaginationMetaGenerator.new(
          request:, records: ckb_transactions,
          page:, page_size:,
          records_counter:
        ).call
        response_transaction = CkbTransactionsSerializer.new(
          ckb_transactions,
          options.merge(params: { previews: true }),
        ).serialized_json

        assert_equal response_transaction, response.body
        assert_equal 1, json.dig("meta", "total")
      end

      test "should return the corresponding transactions when address_hash are set" do
        page = 1
        page_size = 10
        block = create(:block, :with_block_hash)
        ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block:)
        account_book = ckb_transaction.account_books.sample

        ckb_transactions = block.ckb_transactions.joins(:account_books).
          where(account_books: { address_id: account_book.address_id })
        records_counter = RecordCounters::BlockTransactions.new(ckb_transactions)
        ckb_transactions = ckb_transactions.page(page).per(page_size).fast_page

        valid_get api_v1_block_transaction_url(block.block_hash), params: {
          page:, page_size:,
          address_hash: account_book.address.address_hash
        }

        options = FastJsonapi::PaginationMetaGenerator.new(
          request:, records: ckb_transactions,
          page:, page_size:,
          records_counter:
        ).call
        response_transaction = CkbTransactionsSerializer.new(
          ckb_transactions,
          options.merge(params: { previews: true }),
        ).serialized_json

        assert_equal response_transaction, response.body
        assert_equal 1, json.dig("meta", "total")
      end

      test "first tx should be cellbase" do
        page = 1
        page_size = 10
        block = create(:block, :with_block_hash)
        _ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block:)
        _cellbase_ckb_transaction = create(:ckb_transaction, block:, is_cellbase: true)

        valid_get api_v1_block_transaction_url(block.block_hash), params: {
          page:, page_size:
        }

        assert_equal true, json.dig("data").first["attributes"]["is_cellbase"]
      end
    end
  end
end
