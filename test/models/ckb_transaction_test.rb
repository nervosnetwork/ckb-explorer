require "test_helper"

class CkbTransactionTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:block)
    should have_many(:account_books)
    should have_many(:addresses).
      through(:account_books)
    should have_many(:cell_inputs)
    should have_many(:cell_outputs)
  end

  test "#tx_hash should decodes packed string" do
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
      CkbSync::NodeDataProcessor.new.process_block(node_block)
      block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      ckb_transaction = block.ckb_transactions.first
      assert_equal unpack_attribute(ckb_transaction, "tx_hash"), ckb_transaction.tx_hash
    end
  end

  test "#display_inputs should return up to ten records when previews is true" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)

    assert_equal 10, ckb_transaction.display_inputs(previews: true).count
  end

  test "#display_inputs should return all records when previews is false" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)

    assert_equal 15, ckb_transaction.display_inputs.count
  end

  test "#display_outputs should return up to ten records when previews is true" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)

    assert_equal 10, ckb_transaction.display_outputs(previews: true).count
  end

  test "#display_outputs should return all records when previews is false" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)

    assert_equal 15, ckb_transaction.display_outputs.count
  end

  test "#display_inputs should contain correct attributes for normal transaction" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash cell_type)

    assert_equal [expected_attributes], ckb_transaction.display_inputs.map(&:keys).uniq
  end

  test "#display_inputs should contain correct attributes for cellbase" do
    ckb_transaction = create(:ckb_transaction, :with_single_output, is_cellbase: true)
    expected_attributes = %i(id from_cellbase capacity address_hash target_block_number generated_tx_hash)

    assert_equal [expected_attributes], ckb_transaction.display_inputs.map(&:keys).uniq
  end

  test "#display_outputs should contain correct attributes for normal transaction" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    expected_attributes = %i(id capacity address_hash status consumed_tx_hash cell_type).sort

    assert_equal [expected_attributes], ckb_transaction.display_outputs.map(&:keys).map(&:sort).uniq.sort
  end

  test "#display_outputs should contain correct attributes for cellbase" do
    ckb_transaction = create(:ckb_transaction, :with_single_output, is_cellbase: true)
    expected_attributes = %i(id capacity address_hash target_block_number base_reward commit_reward proposal_reward secondary_reward status consumed_tx_hash)

    assert_equal [expected_attributes], ckb_transaction.display_outputs.map(&:keys).uniq
  end

  test "#display_inputs should return correct generated_tx_hash" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    expected_tx_hashes = ckb_transaction.cell_inputs.map(&:previous_cell_output).map(&:generated_by).map(&:tx_hash).sort

    assert_equal expected_tx_hashes, ckb_transaction.display_inputs.pluck(:generated_tx_hash).sort
  end

  test "#display_outputs should return live when cell not be consumed" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)

    assert_equal ["live"], ckb_transaction.display_outputs.pluck(:status).uniq
  end

  test "#display_outputs should not return consumed_tx_hash when cell not be consumed" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)

    assert_equal [nil], ckb_transaction.display_outputs.pluck(:consumed_tx_hash).uniq
  end

  test "#display_outputs should return dead when cell be consumed" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    block = create(:block, :with_block_hash)
    consumed_tx = create(:ckb_transaction, block: block)
    ckb_transaction.outputs.update(consumed_by: consumed_tx, status: "dead")

    assert_equal ["dead"], ckb_transaction.display_outputs.pluck(:status).uniq
  end

  test "#display_inputs order should be the same as inputs in the tx" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    expected_output_is = ckb_transaction.cell_inputs.map(&:previous_cell_output).map(&:id).sort

    assert_equal expected_output_is, ckb_transaction.display_inputs.map{ |display_input| display_input[:id] }
  end

  test "#display_inputs should return dao display input when cell type is dao" do
    prepare_node_data(11)
    CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("800001000")
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, header_deps: %w(0xf85f8fe0d85a73a93e0a289ef14b4fb94228e47098a8da38986d6229c5606ea2 0x83dcd4378e31ed9426df6acfaf0f8d2a028bf3c479ec21430eb03d562bb5bde9))
    dao_input = ckb_transaction.inputs.first
    witness = ckb_transaction.witnesses.first
    started_block_number = Block.find(dao_input.block_id).number
    ended_block_hash = ckb_transaction.header_deps[witness["data"].last.hex]
    ended_block_number = Block.find_by(block_hash: ended_block_hash).number
    dao_input.update(cell_type: "dao")
    out_point = CKB::Types::OutPoint.new(tx_hash: dao_input.tx_hash, index: dao_input.cell_index)
    subsidy = CkbSync::Api.instance.calculate_dao_maximum_withdraw(out_point, ended_block_hash).to_i - dao_input.capacity.to_i

    expected_display_input = { id: dao_input.id, from_cellbase: false, capacity: dao_input.capacity, address_hash: dao_input.address_hash, generated_tx_hash: dao_input.generated_by.tx_hash, started_block_number: started_block_number, ended_block_number: ended_block_number, subsidy: subsidy, cell_type: dao_input.cell_type, dao_type_hash: ENV["DAO_TYPE_HASH"] }.sort
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash started_block_number ended_block_number subsidy cell_type dao_type_hash).sort

    assert_equal expected_attributes, ckb_transaction.display_inputs.first.keys.sort
    assert_equal expected_display_input, ckb_transaction.display_inputs.first.sort
  end

  test "#display_outputs should contain dao attributes for dao transaction" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    dao_output = ckb_transaction.outputs.first
    dao_output.update(cell_type: "dao")
    expected_attributes = %i(id capacity address_hash status consumed_tx_hash cell_type dao_type_hash).sort
    consumed_tx_hash = dao_output.live? ? nil : dao_output.consumed_by.tx_hash
    expected_display_output = { id: dao_output.id, capacity: dao_output.capacity, address_hash: dao_output.address_hash, status: dao_output.status, consumed_tx_hash: consumed_tx_hash, cell_type: dao_output.cell_type, dao_type_hash: ENV["DAO_TYPE_HASH"] }.sort

    assert_equal expected_attributes, ckb_transaction.display_outputs.first.keys.sort
    assert_equal expected_display_output, ckb_transaction.display_outputs.first.sort
  end
end
