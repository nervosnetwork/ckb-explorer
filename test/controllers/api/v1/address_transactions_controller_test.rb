require "test_helper"

module Api
  module V1
    class AddressTransactionsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        address = create(:address, :with_transactions)

        valid_get api_v1_address_transaction_url(address.address_hash)

        assert_response :success
      end

      test "should set right content type when call show" do
        address = create(:address, :with_transactions)

        valid_get api_v1_address_transaction_url(address.address_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        address = create(:address, :with_transactions)

        get api_v1_address_transaction_url(address.address_hash), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        address = create(:address, :with_transactions)
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_address_transaction_url(address.address_hash), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        address = create(:address, :with_transactions)

        get api_v1_address_transaction_url(address.address_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        address = create(:address, :with_transactions)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_address_transaction_url(address.address_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a address hash" do
        error_object = Api::V1::Exceptions::AddressHashInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_transaction_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return corresponding ckb transactions with given address hash" do
        page = 1
        page_size = 10
        address = create(:address, :with_transactions)
        ckb_transactions = address.ckb_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_transaction_url(address.address_hash)

        records_counter = RecordCounters::AddressTransactions.new(address)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: page, page_size: page_size, records_counter: records_counter).call

        assert_equal CkbTransactionsSerializer.new(ckb_transactions, options.merge(params: { previews: true, address: address })).serialized_json, response.body
      end

      test "should return corresponding ckb transactions with given lock hash" do
        page = 1
        page_size = 10
        address = create(:address, :with_transactions)
        ckb_transactions = address.ckb_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_transaction_url(address.lock_hash)

        records_counter = RecordCounters::AddressTransactions.new(address)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: page, page_size: page_size, records_counter: records_counter).call

        assert_equal CkbTransactionsSerializer.new(ckb_transactions, options.merge(params: { previews: true, address: address })).serialized_json, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        address = create(:address, :with_transactions)

        valid_get api_v1_address_transaction_url(address.address_hash)

        response_tx_transaction = json["data"].first

        assert_equal %w(block_number transaction_hash block_timestamp display_inputs display_outputs is_cellbase income).sort, response_tx_transaction["attributes"].keys.sort
      end

      test "should return correct income" do
        address = create(:address)

        block = create(:block, :with_block_hash)
        generated_ckb_transaction = create(:ckb_transaction, block: block, block_timestamp: "1567131126594", contained_address_ids: [address.id])
        create(:cell_output, capacity: 10**8 * 8, ckb_transaction: generated_ckb_transaction, block: generated_ckb_transaction.block, tx_hash: generated_ckb_transaction.tx_hash, cell_index: 0, generated_by: generated_ckb_transaction, address: address)
        consumed_ckb_transaction = create(:ckb_transaction, block: block, block_timestamp: "1567131126595", contained_address_ids: [address.id])

        generated_ckb_transaction1 = create(:ckb_transaction, block: block, block_timestamp: "1567131126596", contained_address_ids: [address.id])
        create(:cell_output, capacity: 10**8 * 8, ckb_transaction: generated_ckb_transaction1, block: generated_ckb_transaction1.block, tx_hash: generated_ckb_transaction1.tx_hash, cell_index: 0, generated_by: generated_ckb_transaction1, address: address)
        create(:cell_output, capacity: 10**8 * 6, ckb_transaction: consumed_ckb_transaction, block: consumed_ckb_transaction.block, tx_hash: consumed_ckb_transaction.tx_hash, cell_index: 0, generated_by: generated_ckb_transaction, consumed_by: consumed_ckb_transaction, address: address)
        address.ckb_transactions << [generated_ckb_transaction1, consumed_ckb_transaction, generated_ckb_transaction]

        valid_get api_v1_address_transaction_url(address.address_hash)

        expected_incomes = address.ckb_transactions.recent.distinct.map { |transaction| transaction.outputs.sum(:capacity) - transaction.inputs.sum(:capacity) }.map(&:to_i)
        actual_incomes = json["data"].map { |transaction| transaction["attributes"]["income"].to_i }

        assert_equal expected_incomes, actual_incomes
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::AddressNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_transaction_url("ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83")

        assert_equal response_json, response.body
      end

      test "should return error object when page param is invalid" do
        address = create(:address, :with_transactions)
        error_object = Api::V1::Exceptions::PageParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_transaction_url(address.address_hash), params: { page: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page size param is invalid" do
        address = create(:address, :with_transactions)
        error_object = Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_address_transaction_url(address.address_hash), params: { page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page and page size param are invalid" do
        errors = []
        address = create(:address, :with_transactions)
        errors << Api::V1::Exceptions::PageParamError.new
        errors << Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new(errors, message: errors.first.title).serialized_json

        valid_get api_v1_address_transaction_url(address.address_hash), params: { page: "bbb", page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return 10 records when page and page_size are not set" do
        address = create(:address, :with_transactions, transactions_count: 15)

        valid_get api_v1_address_transaction_url(address.address_hash)

        assert_equal 10, json["data"].size
      end

      test "should return corresponding page's records when page is set and page_size is not set" do
        page = 2
        page_size = 10
        address = create(:address, :with_transactions, transactions_count: 30)
        address_ckb_transactions = address.custom_ckb_transactions.order("block_timestamp desc nulls last, id desc").page(page).per(page_size)
        valid_get api_v1_address_transaction_url(address.address_hash), params: { page: page }

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_ckb_transactions, page: page, page_size: page_size).call
        response_transaction = CkbTransactionsSerializer.new(address_ckb_transactions, options.merge(params: { previews: true, address: address })).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions under the address when page is not set and page_size is set" do
        page = 1
        page_size = 12
        address = create(:address, :with_transactions, transactions_count: 15)
        address_ckb_transactions = address.ckb_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_transaction_url(address.address_hash), params: { page_size: page_size }

        records_counter = RecordCounters::AddressTransactions.new(address)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_ckb_transactions, page: page, page_size: page_size, records_counter: records_counter).call
        response_transaction = CkbTransactionsSerializer.new(address_ckb_transactions, options.merge(params: { previews: true, address: address })).serialized_json

        assert_equal response_transaction, response.body
        assert_equal page_size, json["data"].size
      end

      test "should return the corresponding transactions when page and page_size are set" do
        page = 2
        page_size = 5
        address = create(:address, :with_transactions, transactions_count: 30)
        address_ckb_transactions = address.ckb_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_transaction_url(address.address_hash), params: { page: page, page_size: page_size }

        records_counter = RecordCounters::AddressTransactions.new(address)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_ckb_transactions, page: page, page_size: page_size, records_counter: records_counter).call
        response_transaction = CkbTransactionsSerializer.new(address_ckb_transactions, options.merge(params: { previews: true, address: address })).serialized_json

        assert_equal response_transaction, response.body
      end

      test "should return empty array when there is no record under the address" do
        page = 2
        page_size = 5
        address = create(:address, :with_transactions)
        address_ckb_transactions = address.ckb_transactions.order(block_timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_address_transaction_url(address.address_hash), params: { page: page, page_size: page_size }

        records_counter = RecordCounters::AddressTransactions.new(address)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: address_ckb_transactions, page: page, page_size: page_size, records_counter: records_counter).call
        response_transaction = CkbTransactionsSerializer.new(address_ckb_transactions, options.merge(params: { previews: true, address: address })).serialized_json

        assert_equal [], json["data"]
        assert_equal response_transaction, response.body
      end

      test "should return meta that contained total in response body" do
        address = create(:address, :with_transactions, transactions_count: 3)

        valid_get api_v1_address_transaction_url(address.address_hash)

        assert_equal 3, json.dig("meta", "total")
      end

      test "should return up to ten display_inputs" do
        address = create(:address)
        block = create(:block, :with_block_hash)
        ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: block, contained_address_ids: [address.id])
        address.ckb_transactions << ckb_transaction

        valid_get api_v1_address_transaction_url(address.address_hash)

        assert_equal 10, json["data"].first.dig("attributes", "display_inputs").count
        assert_equal [true], json["data"].first.dig("attributes", "display_inputs").map { |input| input.key?("from_cellbase") }.uniq
      end

      test "should return up to ten display_outputs" do
        address = create(:address)
        block = create(:block, :with_block_hash)
        ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: block, contained_address_ids: [address.id])
        address.ckb_transactions << ckb_transaction

        valid_get api_v1_address_transaction_url(address.address_hash)

        assert_equal 10, json["data"].first.dig("attributes", "display_outputs").count
        assert_equal [false], json["data"].first.dig("attributes", "display_outputs").map { |input| input.key?("from_cellbase") }.uniq
      end
    end
  end
end


-"{\"data\":[{\"id\":\"3931\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0xebe1ce18b4de3fe266258bd0c30b2d5bda23c7ec34fa6364b8823cd689108e97\",\"block_number\":\"\",\"block_timestamp\":\"1608702821\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3930\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x9c16dfdb717b38b1c7f9f084b99680a3ed9947f6116f1b9b8aaa5fcc51bf9ff5\",\"block_number\":\"\",\"block_timestamp\":\"1608702820\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3929\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x0befe00a477361105609137ae563812bcd540654545887da285ed0a2a821aa4e\",\"block_number\":\"\",\"block_timestamp\":\"1608702819\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3928\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x0fec560589635e368a96f875c180a3d2a54c47c32dc2c32ed155db463084219b\",\"block_number\":\"\",\"block_timestamp\":\"1608702818\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3927\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0xd5629436dea64aa087777292c07b9537a37a2a8378dd741f0671658a081b493f\",\"block_number\":\"\",\"block_timestamp\":\"1608702817\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3926\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x6cf5c589d60f03a68d54f80e58db2caaf0ff339c1d7e53fcc71f18a87e1c94d5\",\"block_number\":\"\",\"block_timestamp\":\"1608702816\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3925\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0xfdaa7245c7ccad26641025ba8eb8aedac0bffa84aeeb8df0036d3db857f7cd55\",\"block_number\":\"\",\"block_timestamp\":\"1608702815\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3924\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x5efd9157ae3baa004c6039d97ea133e2b8f54a9305b83a04b20e2c79fff25ef7\",\"block_number\":\"\",\"block_timestamp\":\"1608702814\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3923\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x9867fecc0a8f9f2403b8284eef3b607f868ccdd163cfa8401fa6f20f3ca5f8f8\",\"block_number\":\"\",\"block_timestamp\":\"1608702813\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3922\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0xff5f3e938cc75406160046db03a06204ac5c6789162cc396c8b6c3a6552a0738\",\"block_number\":\"\",\"block_timestamp\":\"1608702812\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}}],\"meta\":{\"total\":30,\"page_size\":10}}"
+"{\"data\":[{\"id\":\"3930\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x9c16dfdb717b38b1c7f9f084b99680a3ed9947f6116f1b9b8aaa5fcc51bf9ff5\",\"block_number\":\"\",\"block_timestamp\":\"1608702820\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3929\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x0befe00a477361105609137ae563812bcd540654545887da285ed0a2a821aa4e\",\"block_number\":\"\",\"block_timestamp\":\"1608702819\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3928\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x0fec560589635e368a96f875c180a3d2a54c47c32dc2c32ed155db463084219b\",\"block_number\":\"\",\"block_timestamp\":\"1608702818\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3927\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0xd5629436dea64aa087777292c07b9537a37a2a8378dd741f0671658a081b493f\",\"block_number\":\"\",\"block_timestamp\":\"1608702817\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3926\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x6cf5c589d60f03a68d54f80e58db2caaf0ff339c1d7e53fcc71f18a87e1c94d5\",\"block_number\":\"\",\"block_timestamp\":\"1608702816\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3925\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0xfdaa7245c7ccad26641025ba8eb8aedac0bffa84aeeb8df0036d3db857f7cd55\",\"block_number\":\"\",\"block_timestamp\":\"1608702815\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3924\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x5efd9157ae3baa004c6039d97ea133e2b8f54a9305b83a04b20e2c79fff25ef7\",\"block_number\":\"\",\"block_timestamp\":\"1608702814\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3923\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x9867fecc0a8f9f2403b8284eef3b607f868ccdd163cfa8401fa6f20f3ca5f8f8\",\"block_number\":\"\",\"block_timestamp\":\"1608702813\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3922\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0xff5f3e938cc75406160046db03a06204ac5c6789162cc396c8b6c3a6552a0738\",\"block_number\":\"\",\"block_timestamp\":\"1608702812\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}},{\"id\":\"3921\",\"type\":\"ckb_transactions\",\"attributes\":{\"is_cellbase\":false,\"transaction_hash\":\"0x28daf2d5c31539d557e4584fea8d3599f0614be40de5e5b02c644bab9049689a\",\"block_number\":\"\",\"block_timestamp\":\"1608702811\",\"display_inputs\":[],\"display_outputs\":[],\"income\":\"0.0\"}}],\"meta\":{\"total\":30,\"page_size\":10}}"