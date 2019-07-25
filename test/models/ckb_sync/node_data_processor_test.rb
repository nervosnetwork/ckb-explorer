require "test_helper"

module CkbSync
  class NodeDataProcessorTest < ActiveSupport::TestCase
    test "#call should create one block" do
      assert_difference -> { Block.count }, 1 do
        VCR.use_cassette("blocks/10") do
          node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
          node_data_processor.call(node_block)
        end
      end
    end

    test "#call created block's attribute value should equal with the node block's attribute value" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        local_block = node_data_processor.call(node_block)

        node_block = node_block.to_h.deep_stringify_keys
        formatted_node_block = format_node_block(node_block)
        epoch_info = CkbUtils.get_epoch_info(formatted_node_block["epoch"])
        formatted_node_block["start_number"] = epoch_info.start_number
        formatted_node_block["length"] = epoch_info.length

        local_block_hash = local_block.attributes.select { |attribute| attribute.in?(%w(difficulty block_hash number parent_hash seal timestamp transactions_root proposals_hash uncles_count uncles_hash version proposals witnesses_root epoch start_number length dao)) }
        local_block_hash["hash"] = local_block_hash.delete("block_hash")
        local_block_hash["number"] = local_block_hash["number"].to_s
        local_block_hash["version"] = local_block_hash["version"].to_s
        local_block_hash["uncles_count"] = local_block_hash["uncles_count"].to_s
        local_block_hash["epoch"] = local_block_hash["epoch"].to_s
        local_block_hash["timestamp"] = local_block_hash["timestamp"].to_s

        assert_equal formatted_node_block.sort, local_block_hash.sort
      end
    end

    test "#call created block's proposals_count should equal with the node block's proposals size" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)

        local_block = node_data_processor.call(node_block)

        assert_equal node_block.proposals.size, local_block.proposals_count
      end
    end

    test "#call should generate miner's address when cellbase has witnesses" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      VCR.use_cassette("blocks/11") do
        node_block = CkbSync::Api.instance.get_block("0xd895e3fd670fd499567ce219cf8a8e6da27a91e1679ed01088fdcd1b072d3c4c")
        local_block = node_data_processor.call(node_block)
        expected_miner_hash = CkbUtils.miner_hash(node_block.transactions.first)

        assert expected_miner_hash, local_block.miner_hash
      end
    end

    test "#call should generate miner's lock when cellbase has witnesses" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      VCR.use_cassette("blocks/11") do
        node_block = CkbSync::Api.instance.get_block("0xd895e3fd670fd499567ce219cf8a8e6da27a91e1679ed01088fdcd1b072d3c4c")
        expected_miner_lock_hash = CkbUtils.miner_lock_hash(node_block.transactions.first)
        block = node_data_processor.call(node_block)

        assert_equal expected_miner_lock_hash, block.miner_lock_hash
      end
    end

    test "#call generated block's total_cell_capacity should equal to the sum of transactions output capacity" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)

        local_block = node_data_processor.call(node_block)
        expected_total_capacity =
          node_block.transactions.reduce(0) do |memo, transaction|
            memo + transaction.outputs.reduce(0) { |inside_memo, output| inside_memo + output.capacity.to_i }
          end

        assert_equal expected_total_capacity, local_block.total_cell_capacity
      end
    end

    private

    def node_data_processor
      CkbSync::NodeDataProcessor.new
    end
  end
end
