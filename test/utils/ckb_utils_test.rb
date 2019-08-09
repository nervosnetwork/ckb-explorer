require "test_helper"

class CkbUtilsTest < ActiveSupport::TestCase
  test "#generate_address should return type1 address when use default lock script" do
    type1_address = "ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83"
    lock_script = CKB::Types::Script.generate_lock(
      "0x36c329ed630d6ce750712a477543672adab57f4c",
      ENV["CODE_HASH"]
    )

    assert_equal type1_address, CkbUtils.generate_address(lock_script)
  end

  test "#base_reward should return first output capacity in cellbase for genesis block" do
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
      CKB::Types::Epoch.new(
        epoch_reward: "250000000000",
        difficulty: "0x1000",
        length: "2000",
        number: "0",
        start_number: "0"
      )
    )
    VCR.use_cassette("genesis_block") do
      node_block = CkbSync::Api.instance.get_block_by_number("0")
      set_default_lock_params(node_block: node_block)

      local_block = CkbSync::NodeDataProcessor.new.process_block(node_block)

      assert_equal node_block.transactions.first.outputs.first.capacity.to_i, local_block.reward
    end
  end

  test "#calculate_cell_min_capacity should return output's min capacity" do
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)

      node_data_processor.process_block(node_block)
      output = node_block.transactions.first.outputs.first
      expected_cell_min_capacity = output.calculate_min_capacity

      assert_equal expected_cell_min_capacity, CkbUtils.calculate_cell_min_capacity(output)
    end
  end


  test "#block_cell_consumed generated block's cell_consumed should equal to the sum of transactions output occupied capacity" do
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)

      node_data_processor.process_block(node_block)
      expected_total_cell_consumed = node_block.transactions.flat_map(&:outputs).flatten.reduce(0) { |memo, output| memo + output.calculate_min_capacity }

      assert_equal expected_total_cell_consumed, CkbUtils.block_cell_consumed(node_block.transactions)
    end
  end

  test "#address_cell_consumed should return right cell consumed by the address" do
    prepare_inauthentic_node_data(12)
    VCR.use_cassette("blocks/12") do
      node_block = CkbSync::Api.instance.get_block_by_number(13)
      cellbase = node_block.transactions.first
      lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
      miner_address = Address.find_or_create_address(lock_script)
      unspent_cells = miner_address.cell_outputs.live
      expected_address_cell_consumed = unspent_cells.reduce(0) { |memo, cell| memo + cell.node_output.calculate_min_capacity }

      assert_equal expected_address_cell_consumed, CkbUtils.address_cell_consumed(miner_address.address_hash)
    end
  end

  private

  def node_data_processor
    CkbSync::NodeDataProcessor.new
  end
end
