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
      output_data = node_block.transactions.first.outputs_data.first
      output.data = output_data
      expected_cell_min_capacity = output.calculate_min_capacity

      assert_equal expected_cell_min_capacity, CkbUtils.calculate_cell_min_capacity(output, output_data)
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
    prepare_node_data(12)
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

  test ".ckb_transaction_fee should return right tx_fee when tx is not dao withdraw tx" do
    node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block)
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)
      node_data_processor.process_block(node_block)
      node_tx = node_block.transactions.last
      ckb_transaction = CkbTransaction.find_by(tx_hash: node_tx.hash)

      assert_equal 10**8 * 3, CkbUtils.ckb_transaction_fee(ckb_transaction)
    end
  end

  test ".ckb_transaction_fee should return right tx_fee when tx is dao withdraw tx" do
    CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("986473")
    node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, cell_type: "dao")
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)
      node_data_processor.process_block(node_block)
      node_tx = node_block.transactions.last
      ckb_transaction = CkbTransaction.find_by(tx_hash: node_tx.hash)

      assert_equal 10**8 * 3 + 986473, CkbUtils.ckb_transaction_fee(ckb_transaction)
    end
  end

  test ".ckb_transaction_fee should return right tx_fee when tx is dao withdraw tx and have multiple dao cell" do
    CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("986473")
    node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 0, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block, cell_type: "dao")
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, cell_type: "dao")
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)
      tx = node_block.transactions.last
      input = CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(cell: CKB::Types::CellOutPoint.new(tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", index: 0)))
      tx.inputs.unshift(input)
      node_data_processor.process_block(node_block)
      node_tx = node_block.transactions.last
      ckb_transaction = CkbTransaction.find_by(tx_hash: node_tx.hash)
      expected_tx_fee = 10**8 * 16 + 986473 * 2 - 10**8 * 5

      assert_equal expected_tx_fee, CkbUtils.ckb_transaction_fee(ckb_transaction)
    end
  end

  private

  def node_data_processor
    CkbSync::NodeDataProcessor.new
  end
end
