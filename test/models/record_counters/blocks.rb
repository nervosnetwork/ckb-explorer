require "test_helper"

class BlockTransactionsTest < ActiveSupport::TestCase
  test "should respond to total_count" do
    create(:block, :with_block_hash)
    blocks_counter = RecordCounters::Blocks.new
    assert_respond_to blocks_counter, :total_count
  end

  test "total_count should return blocks count" do
    create(:table_record_count, :block_counter)
    create(:table_record_count, :ckb_transactions_counter)
    blocks_counter = RecordCounters::Blocks.new

    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x07d0",
          number: "0x0",
          start_number: "0x0"
        )
      )
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      TableRecordCount.find_or_initialize_by(table_name: "blocks").increment!(:count)
      CkbSync::NewNodeDataProcessor.new.process_block(node_block)
      assert_equal Block.count, blocks_counter.total_count
    end
  end
end
