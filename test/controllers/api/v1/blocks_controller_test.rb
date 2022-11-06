require "test_helper"

module Api
  module V1
    class BlocksControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when visit index" do
        valid_get api_v1_blocks_url

        assert_response :success
      end

      test "should set right content type when visit index" do
        valid_get api_v1_blocks_url

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_blocks_url, headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_blocks_url, headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_blocks_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_blocks_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should get serialized objects" do
        15.times do |number|
          create(:block, :with_block_hash, timestamp: 2.days.ago.to_i + number)
        end
        block_timestamps = Block.recent.limit(ENV["HOMEPAGE_BLOCK_RECORDS_COUNT"].to_i).pluck(:timestamp)
        blocks = Block.where(timestamp: block_timestamps).select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count, :live_cell_changes).recent

        valid_get api_v1_blocks_url

        assert_equal BlockListSerializer.new(blocks, {}).serialized_json, response.body
      end

      test "serialized objects should in reverse order of timestamp" do
        timestamp = Time.current.to_i
        create(:block, :with_block_hash, number: 11, timestamp: timestamp)
        create(:block, :with_block_hash, number: 12, timestamp: timestamp + 8.seconds)

        valid_get api_v1_blocks_url

        first_block = json["data"].first
        last_block = json["data"].last
        assert_operator first_block.dig("attributes", "timestamp").to_i, :>, last_block.dig("attributes", "timestamp").to_i
      end

      test "should contain right keys in the serialized object" do
        create(:block)

        valid_get api_v1_blocks_url

        response_block = json["data"].first
        assert_equal %w(number transactions_count reward miner_hash timestamp live_cell_changes).sort, response_block["attributes"].keys.sort
      end

      test "should return error object when page param is invalid" do
        create_list(:block, 15, :with_block_hash)
        error_object = Api::V1::Exceptions::PageParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_blocks_url, params: { page: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page size param is invalid" do
        create_list(:block, 15, :with_block_hash)
        error_object = Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_blocks_url, params: { page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return error object when page and page size param are invalid" do
        errors = []
        create_list(:block, 15, :with_block_hash)
        errors << Api::V1::Exceptions::PageParamError.new
        errors << Api::V1::Exceptions::PageSizeParamError.new
        response_json = RequestErrorSerializer.new(errors, message: errors.first.title).serialized_json

        valid_get api_v1_blocks_url, params: { page: "bbb", page_size: "aaa" }

        assert_equal response_json, response.body
      end

      test "should return 15 records when page and page_size are not set" do
        create_list(:block, 20, :with_block_hash)

        valid_get api_v1_blocks_url

        assert_equal 15, json["data"].size
      end

      test "should return accepted records" do
        page = 1
        page_size = 30
        create_list(:block, 15, :with_block_hash)
        create(:block)
        create(:table_record_count, :block_counter, count: 16)

        valid_get api_v1_blocks_url, params: { page: page, page_size: page_size }

        block_hashes = Block.recent.map(&:number).map(&:to_s)
        search_result_block_numbers = json["data"].map { |block| block.dig("attributes", "number") }

        assert_equal block_hashes, search_result_block_numbers
      end

      test "should return corresponding page's records when page is set and page_size is not set" do
        page = 2
        create_list(:block, 20, :with_block_hash)
        block_timestamps = Block.recent.limit(ENV["HOMEPAGE_BLOCK_RECORDS_COUNT"].to_i).pluck(:timestamp)
        blocks = Block.where(timestamp: block_timestamps).select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count, :live_cell_changes).recent

        valid_get api_v1_blocks_url, params: { page: page }

        response_blocks = BlockListSerializer.new(blocks, {}).serialized_json

        assert_equal response_blocks, response.body
        assert_equal 15, json["data"].size
      end

      test "should return the corresponding number of blocks when page is not set and page_size is set" do
        create_list(:block, 20, :with_block_hash)

        valid_get api_v1_blocks_url, params: { page_size: 12 }

        block_timestamps = Block.recent.limit(ENV["HOMEPAGE_BLOCK_RECORDS_COUNT"].to_i).pluck(:timestamp)
        blocks = Block.where(timestamp: block_timestamps).select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count, :live_cell_changes).recent
        response_blocks = BlockListSerializer.new(blocks, {}).serialized_json
        assert_equal response_blocks, response.body
        assert_equal 15, json["data"].size
      end

      test "should return the corresponding blocks when page and page_size are set" do
        create_list(:block, 15, :with_block_hash)
        create(:table_record_count, :block_counter, count: 15)
        page = 2
        page_size = 5
        block_timestamps = Block.recent.select(:timestamp).page(page).per(page_size)
        blocks = Block.where(timestamp: block_timestamps.map { |block| block.timestamp }).select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count, :live_cell_changes).recent

        valid_get api_v1_blocks_url, params: { page: page, page_size: page_size }

        records_counter = RecordCounters::Blocks.new
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: block_timestamps, page: page, page_size: page_size, records_counter: records_counter).call
        response_blocks = BlockListSerializer.new(blocks, options).serialized_json
        assert_equal response_blocks, response.body
      end

      test "should return empty array when there is no blocks" do
        create(:table_record_count, :block_counter)
        page = 2
        page_size = 5
        blocks = Block.order(timestamp: :desc).page(page).per(page_size)

        valid_get api_v1_blocks_url, params: { page: page, page_size: page_size }

        records_counter = RecordCounters::Blocks.new
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: blocks, page: page, page_size: page_size, records_counter: records_counter).call
        response_blocks = BlockSerializer.new(blocks, options).serialized_json

        assert_equal [], json["data"]
        assert_equal response_blocks, response.body
      end

      test "should return meta that contained total in response body" do
        page = 1
        page_size = 30
        create_list(:block, 30, :with_block_hash)
        create(:table_record_count, :block_counter, count: 30)
        valid_get api_v1_blocks_url, params: { page: page, page_size: page_size }

        assert_equal page_size, json.dig("meta", "total")
      end

      test "should get success code when visit show" do
        block = create(:block)

        valid_get api_v1_block_url(block.block_hash)

        assert_response :success
      end

      test "should set right content type when visit show" do
        valid_get api_v1_block_url(1)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong when visit show" do
        get api_v1_block_url(1), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong when visit show" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_block_url(1), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong when visit show" do
        get api_v1_block_url(1), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong when visit show" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_block_url(1), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a hex start with 0x" do
        error_object = Api::V1::Exceptions::BlockQueryKeyInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_block_url("9034fwefwef")

        assert_equal response_json, response.body
      end

      test "should return error object when id is a hex start with 0x but the length is wrong" do
        error_object = Api::V1::Exceptions::BlockQueryKeyInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_block_url("0xawefwef")

        assert_equal response_json, response.body
      end

      test "should return corresponding block with given block hash" do
        block = create(:block)

        valid_get api_v1_block_url(block.block_hash)

        assert_equal JSON.parse(BlockSerializer.new(block).serialized_json), json
      end

      test "should return corresponding block with given height" do
        block = create(:block)

        valid_get api_v1_block_url(block.number)

        assert_equal JSON.parse(BlockSerializer.new(block).serialized_json), json
      end

      test "should contain right keys in the serialized object when visit show" do
        block = create(:block)

        valid_get api_v1_block_url(block.block_hash)

        response_block = json["data"]
        assert_equal %w(block_hash number transactions_count proposals_count uncles_count uncle_block_hashes reward total_transaction_fee cell_consumed total_cell_capacity miner_hash timestamp difficulty version nonce epoch start_number length transactions_root reward_status received_tx_fee received_tx_fee_status block_index_in_epoch miner_reward miner_message size).sort, response_block["attributes"].keys.sort
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::BlockNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_block_url("0.87")

        assert_equal response_json, response.body
      end
    end
  end
end
