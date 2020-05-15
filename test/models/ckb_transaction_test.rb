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
      create(:block, :with_block_hash, number: node_block.header.number - 1)
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
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash cell_type cell_index).sort

    assert_equal [expected_attributes], ckb_transaction.display_inputs.map(&:keys).map(&:sort).uniq
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

    assert_equal [""], ckb_transaction.display_outputs.pluck(:consumed_tx_hash).uniq
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
    assert_equal expected_output_is.map(&:to_s), ckb_transaction.display_inputs.map { |display_input| display_input[:id] }
  end

  test "#display_inputs should return dao display input when cell type is nervos_dao_withdrawing" do
    prepare_node_data
    CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x177825f000")
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, header_deps: [DEFAULT_NODE_BLOCK_HASH, "0xf85f8fe0d85a73a93e0a289ef14b4fb94228e47098a8da38986d6229c5606ea2"])
    nervos_dao_withdrawing_cell = ckb_transaction.cell_inputs.first.previous_cell_output
    nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.generated_by
    create(:cell_input, block: nervos_dao_withdrawing_cell_generated_tx.block, ckb_transaction: nervos_dao_withdrawing_cell_generated_tx, previous_output: { "tx_hash": "0x398315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e2", "index": "0" })
    ended_block = Block.select(:number, :timestamp).find(nervos_dao_withdrawing_cell_generated_tx.block_id)
    nervos_dao_withdrawing_cell.update(cell_type: "nervos_dao_withdrawing")
    deposit_cell = create(:cell_output, ckb_transaction: nervos_dao_withdrawing_cell.generated_by, cell_index: 0, tx_hash: "0x398315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e2", generated_by: nervos_dao_withdrawing_cell.generated_by, block: nervos_dao_withdrawing_cell.generated_by.block, consumed_by: nervos_dao_withdrawing_cell.generated_by, cell_type: "nervos_dao_deposit", capacity: 10**8 * 1000, data: CKB::Utils.bin_to_hex("\x00" * 8))
    nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.inputs.nervos_dao_deposit.first
    started_block = Block.select(:number, :timestamp).find(nervos_dao_deposit_cell.block_id)
    interest = CkbSync::Api.instance.calculate_dao_maximum_withdraw(deposit_cell, nervos_dao_deposit_cell).hex - deposit_cell.capacity.to_i
    expected_display_input = CkbUtils.hash_value_to_s({
      id: nervos_dao_withdrawing_cell.id, from_cellbase: false, capacity: nervos_dao_withdrawing_cell.capacity,
      address_hash: nervos_dao_withdrawing_cell.address_hash, generated_tx_hash: nervos_dao_withdrawing_cell.generated_by.tx_hash,
      compensation_started_block_number: started_block.number, compensation_ended_block_number: ended_block.number,
      compensation_started_timestamp: started_block.timestamp, compensation_ended_timestamp: ended_block.timestamp,
      locked_until_block_number: ckb_transaction.block.number, locked_until_block_timestamp: ckb_transaction.block.timestamp,
      interest: interest, cell_type: nervos_dao_withdrawing_cell.cell_type, cell_index: nervos_dao_withdrawing_cell.cell_index }).sort
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash compensation_started_block_number compensation_ended_block_number compensation_started_timestamp compensation_ended_timestamp interest cell_type locked_until_block_number locked_until_block_timestamp cell_index).sort

    assert_equal expected_attributes, ckb_transaction.display_inputs.first.keys.sort
    assert_equal expected_display_input, ckb_transaction.display_inputs.first.sort
  end

  test "#display_inputs should return dao display input when previous cell type is nervos_dao_deposit" do
    CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x177825f000")
    block = create(:block, :with_block_hash, timestamp: Time.current.to_i)
    ckb_transaction = create(:ckb_transaction, block: block, tx_hash: "0xe8a116ec65f7d2d0d4748ba2bbcf8691cbd31202908ccfa3a975414fef801042")
    deposit_output_cell = create(:cell_output, block: ckb_transaction.block, capacity: 138 * 10**8, tx_hash: "0xe8a116ec65f7d2d0d4748ba2bbcf8691cbd31202908ccfa3a975414fef801042", cell_index: 0, ckb_transaction: ckb_transaction, generated_by: ckb_transaction, consumed_by: ckb_transaction, cell_type: "nervos_dao_deposit", data: "0x0000000000000000")
    phase1_block = create(:block, block_hash: "0x2ef70da7151f06c26810ea63afa133951e83eb80f85e001a408eac2f34366452", timestamp: Time.current.to_i)
    phase1_transaction = create(:ckb_transaction, block: phase1_block, header_deps: ["0xf85f8fe0d85a73a93e0a289ef14b4fb94228e47098a8da38986d6229c5606ea2"], is_cellbase: false, tx_hash: "0xf9aca16b49c7d037920ad9e5aecdac272412a5fbe0396f7d95b112bf790dd39f")
    create(:cell_input, block: phase1_transaction.block, ckb_transaction: phase1_transaction, previous_output: { index: 0, tx_hash: "0xe8a116ec65f7d2d0d4748ba2bbcf8691cbd31202908ccfa3a975414fef801042" }, from_cell_base: false)
    nervos_dao_withdrawing_cell = create(:cell_output, ckb_transaction: phase1_transaction, block: phase1_transaction.block, capacity: 13800000000, data: "0x7512000000000000", tx_hash: "0xf9aca16b49c7d037920ad9e5aecdac272412a5fbe0396f7d95b112bf790dd39f", cell_index: 0, generated_by: phase1_transaction, cell_type: "nervos_dao_withdrawing")
    started_block = Block.select(:number, :timestamp).find(ckb_transaction.block_id)
    interest = CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
    ended_block = Block.select(:number, :timestamp).find(phase1_transaction.block_id)
    expected_display_input = CkbUtils.hash_value_to_s({
      id: deposit_output_cell.id, from_cellbase: false, capacity: deposit_output_cell.capacity,
      address_hash: deposit_output_cell.address_hash, generated_tx_hash: deposit_output_cell.generated_by.tx_hash,
      compensation_started_block_number: started_block.number, compensation_ended_block_number: ended_block.number,
      compensation_started_timestamp: started_block.timestamp, compensation_ended_timestamp: ended_block.timestamp,
      interest: interest, cell_type: deposit_output_cell.cell_type, cell_index: deposit_output_cell.cell_index }).sort
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash interest cell_type compensation_ended_block_number compensation_ended_timestamp compensation_started_block_number compensation_started_timestamp cell_index).sort

    assert_equal expected_attributes, phase1_transaction.display_inputs.first.keys.sort
    assert_equal expected_display_input, phase1_transaction.display_inputs.first.sort
  end

  test "#display_outputs should contain dao attributes for dao transaction" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    dao_output = ckb_transaction.outputs.first
    dao_output.update(cell_type: "nervos_dao_withdrawing")
    expected_attributes = %i(id capacity address_hash status consumed_tx_hash cell_type).sort
    consumed_tx_hash = dao_output.live? ? nil : dao_output.consumed_by.tx_hash
    expected_display_output = CkbUtils.hash_value_to_s({ id: dao_output.id, capacity: dao_output.capacity, address_hash: dao_output.address_hash, status: dao_output.status, consumed_tx_hash: consumed_tx_hash, cell_type: dao_output.cell_type }).sort

    assert_equal expected_attributes, ckb_transaction.display_outputs.first.keys.sort
    assert_equal expected_display_output, ckb_transaction.display_outputs.first.sort
  end

  test "#display_inputs should contain udt attributes for udt transaction" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    udt_input_block = create(:block, :with_block_hash)
    udt_input_transaction = create(:ckb_transaction, block: udt_input_block)
    udt_cell_output = create(:cell_output, block: udt_input_block, ckb_transaction: udt_input_transaction, consumed_by: ckb_transaction, generated_by: udt_input_transaction, cell_type: "udt", cell_index: 0, tx_hash: udt_input_transaction.tx_hash, data: "0x000050ad321ea12e0000000000000000", type_hash: "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8")
    type_script = create(:type_script, cell_output: udt_cell_output)
    create(:udt, code_hash: type_script.code_hash)

    cell_input = ckb_transaction.cell_inputs.first
    cell_input.update(previous_output: { "tx_hash": udt_input_transaction.tx_hash, "index": "0" })
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash udt_info cell_index cell_type).sort
    expected_udt_attributes = %i(symbol amount decimal type_hash published).sort
    expected_display_input = CkbUtils.hash_value_to_s({ id: udt_cell_output.id, from_cellbase: false, capacity: udt_cell_output.capacity, address_hash: udt_cell_output.address_hash, generated_tx_hash: udt_cell_output.generated_by.tx_hash, cell_index: udt_cell_output.cell_index, cell_type: udt_cell_output.cell_type, udt_info: udt_cell_output.udt_info })

    assert_equal expected_attributes, ckb_transaction.display_inputs.first.keys.sort
    assert_equal expected_udt_attributes, ckb_transaction.display_inputs.first[:udt_info].keys.sort
    assert_equal expected_display_input, ckb_transaction.display_inputs.first
  end

  test "#display_outputs should contain udt attributes for udt transaction" do
    udt_output_block = create(:block, :with_block_hash)
    udt_output_transaction = create(:ckb_transaction, block: udt_output_block)
    udt_cell_output = create(:cell_output, block: udt_output_block, ckb_transaction: udt_output_transaction, generated_by: udt_output_transaction, cell_type: "udt", cell_index: 0, tx_hash: udt_output_transaction.tx_hash, data: "0x000050ad321ea12e0000000000000000", type_hash: "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8")
    type_script = create(:type_script, cell_output: udt_cell_output)
    create(:udt, code_hash: type_script.code_hash)

    expected_attributes = %i(id capacity address_hash status consumed_tx_hash cell_type udt_info).sort
    expected_udt_attributes = %i(symbol amount decimal type_hash published).sort
    expected_display_input = CkbUtils.hash_value_to_s({ id: udt_cell_output.id, capacity: udt_cell_output.capacity, address_hash: udt_cell_output.address_hash, status: udt_cell_output.status, consumed_tx_hash: nil, cell_type: udt_cell_output.cell_type, udt_info: udt_cell_output.udt_info })

    assert_equal expected_attributes, udt_output_transaction.display_outputs.first.keys.sort
    assert_equal expected_udt_attributes, udt_output_transaction.display_outputs.first[:udt_info].keys.sort
    assert_equal expected_display_input, udt_output_transaction.display_outputs.first
  end
end
