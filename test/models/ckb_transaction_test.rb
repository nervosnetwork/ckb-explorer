require "test_helper"

class CkbTransactionTest < ActiveSupport::TestCase
  setup do
    create(:table_record_count, :block_counter)
    create(:table_record_count, :ckb_transactions_counter)
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
  end

  context "associations" do
    should belong_to(:block)
    should have_many(:account_books)
    should have_many(:addresses).
      through(:account_books)
    should have_many(:cell_inputs)
    should have_many(:cell_outputs)
  end

  test "#tx_hash should decodes packed string" do
    GenerateStatisticsDataWorker.any_instance.stubs(:perform).returns(true)
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
      CkbSync::NewNodeDataProcessor.new.process_block(node_block)
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
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash cell_type cell_index since).sort

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
    prepare_node_data
    block = Block.last
    ckb_transaction = create(:ckb_transaction, :with_single_output, is_cellbase: true, block: block)
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
    DaoCompensationCalculator.any_instance.stubs(:call).returns(100800000000)
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, header_deps: [DEFAULT_NODE_BLOCK_HASH, "0xf85f8fe0d85a73a93e0a289ef14b4fb94228e47098a8da38986d6229c5606ea2"])
    nervos_dao_withdrawing_cell = ckb_transaction.cell_inputs.first.previous_cell_output
    nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.generated_by
    create(:cell_input, block: nervos_dao_withdrawing_cell_generated_tx.block, ckb_transaction: nervos_dao_withdrawing_cell_generated_tx, previous_output: { "tx_hash": "0x398315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e2", "index": "0" })
    ended_block = Block.select(:number, :timestamp).find(nervos_dao_withdrawing_cell_generated_tx.block_id)
    nervos_dao_withdrawing_cell.update(cell_type: "nervos_dao_withdrawing")
    deposit_cell = create(:cell_output, ckb_transaction: nervos_dao_withdrawing_cell.generated_by, cell_index: 0, tx_hash: "0x398315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e2", generated_by: nervos_dao_withdrawing_cell.generated_by, block: nervos_dao_withdrawing_cell.generated_by.block, consumed_by: nervos_dao_withdrawing_cell.generated_by, cell_type: "nervos_dao_deposit", capacity: 10**8 * 1000, data: CKB::Utils.bin_to_hex("\x00" * 8))
    nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.inputs.nervos_dao_deposit.first
    started_block = Block.select(:number, :timestamp).find(nervos_dao_deposit_cell.block_id)
    interest = DaoCompensationCalculator.new(deposit_cell, nervos_dao_withdrawing_cell.block.dao).call
    expected_display_input = CkbUtils.hash_value_to_s(
      id: nervos_dao_withdrawing_cell.id, from_cellbase: false, capacity: nervos_dao_withdrawing_cell.capacity,
      address_hash: nervos_dao_withdrawing_cell.address_hash, generated_tx_hash: nervos_dao_withdrawing_cell.generated_by.tx_hash,
      compensation_started_block_number: started_block.number, compensation_ended_block_number: ended_block.number,
      compensation_started_timestamp: started_block.timestamp, compensation_ended_timestamp: ended_block.timestamp,
      locked_until_block_number: ckb_transaction.block.number, locked_until_block_timestamp: ckb_transaction.block.timestamp,
      interest: interest, cell_type: nervos_dao_withdrawing_cell.cell_type, cell_index: nervos_dao_withdrawing_cell.cell_index,
      since: {raw: "0x0000000000000000", median_timestamp: "0"}
    ).sort
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash compensation_started_block_number compensation_ended_block_number compensation_started_timestamp compensation_ended_timestamp interest cell_type locked_until_block_number locked_until_block_timestamp cell_index since).sort
    display_inputs = ckb_transaction.display_inputs
    assert_equal expected_attributes, display_inputs.first.keys.sort
    assert_equal expected_display_input, display_inputs.first.sort
  end

  test "#display_inputs should return dao display input when previous cell type is nervos_dao_deposit" do
    DaoCompensationCalculator.any_instance.stubs(:call).returns(100800000000)
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
    expected_display_input = CkbUtils.hash_value_to_s(
      id: deposit_output_cell.id, from_cellbase: false, capacity: deposit_output_cell.capacity,
      address_hash: deposit_output_cell.address_hash, generated_tx_hash: deposit_output_cell.generated_by.tx_hash,
      compensation_started_block_number: started_block.number, compensation_ended_block_number: ended_block.number,
      compensation_started_timestamp: started_block.timestamp, compensation_ended_timestamp: ended_block.timestamp,
      interest: interest, cell_type: deposit_output_cell.cell_type, cell_index: deposit_output_cell.cell_index,
      since: { raw: "0x0000000000000000", median_timestamp: "0"}
    ).sort
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash interest cell_type compensation_ended_block_number compensation_ended_timestamp compensation_started_block_number compensation_started_timestamp cell_index since).sort

    assert_equal expected_attributes, phase1_transaction.display_inputs.first.keys.sort
    assert_equal expected_display_input, phase1_transaction.display_inputs.first.sort
  end

  test "#display_outputs should contain dao attributes for dao transaction" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    dao_output = ckb_transaction.outputs.first
    dao_output.update(cell_type: "nervos_dao_withdrawing")
    expected_attributes = %i(id capacity address_hash status consumed_tx_hash cell_type).sort
    consumed_tx_hash = dao_output.live? ? nil : dao_output.consumed_by.tx_hash
    expected_display_output = CkbUtils.hash_value_to_s(id: dao_output.id, capacity: dao_output.capacity, address_hash: dao_output.address_hash, status: dao_output.status, consumed_tx_hash: consumed_tx_hash, cell_type: dao_output.cell_type).sort
    display_outputs = ckb_transaction.display_outputs
    assert_equal expected_attributes, display_outputs.first.keys.sort
    assert_equal expected_display_output, display_outputs.first.sort
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
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash udt_info cell_index cell_type since).sort
    expected_udt_attributes = %i(symbol amount decimal type_hash published display_name uan).sort
    expected_display_input = CkbUtils.hash_value_to_s(id: udt_cell_output.id, from_cellbase: false, capacity: udt_cell_output.capacity, address_hash: udt_cell_output.address_hash, generated_tx_hash: udt_cell_output.generated_by.tx_hash, cell_index: udt_cell_output.cell_index, cell_type: udt_cell_output.cell_type, udt_info: udt_cell_output.udt_info, since: {raw: "0x0000000000000000", median_timestamp: "0"})
    display_inputs = ckb_transaction.display_inputs
    assert_equal expected_attributes, display_inputs.first.keys.sort
    assert_equal expected_udt_attributes, display_inputs.first[:udt_info].keys.sort
    assert_equal expected_display_input, display_inputs.first
  end

  test "#display_outputs should contain udt attributes for udt transaction" do
    udt_output_block = create(:block, :with_block_hash)
    udt_output_transaction = create(:ckb_transaction, block: udt_output_block)
    udt_cell_output = create(:cell_output, block: udt_output_block, ckb_transaction: udt_output_transaction, generated_by: udt_output_transaction, cell_type: "udt", cell_index: 0, tx_hash: udt_output_transaction.tx_hash, data: "0x000050ad321ea12e0000000000000000", type_hash: "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8")
    type_script = create(:type_script, cell_output: udt_cell_output)
    create(:udt, code_hash: type_script.code_hash)

    expected_attributes = %i(id capacity address_hash status consumed_tx_hash cell_type udt_info).sort
    expected_udt_attributes = %i(symbol amount decimal type_hash published display_name uan).sort
    expected_display_input = CkbUtils.hash_value_to_s(id: udt_cell_output.id, capacity: udt_cell_output.capacity, address_hash: udt_cell_output.address_hash, status: udt_cell_output.status, consumed_tx_hash: nil, cell_type: udt_cell_output.cell_type, udt_info: udt_cell_output.udt_info)

    assert_equal expected_attributes, udt_output_transaction.display_outputs.first.keys.sort
    assert_equal expected_udt_attributes, udt_output_transaction.display_outputs.first[:udt_info].keys.sort
    assert_equal expected_display_input, udt_output_transaction.display_outputs.first
  end

  test "#display_inputs should contain m_nft_issuer info for m_nft_issuer transaction" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    m_nft_input_block = create(:block, :with_block_hash)
    m_nft_input_transaction = create(:ckb_transaction, block: m_nft_input_block)
    m_nft_cell_output = create(:cell_output, block: m_nft_input_block, ckb_transaction: m_nft_input_transaction, consumed_by: ckb_transaction, generated_by: m_nft_input_transaction, cell_type: "m_nft_issuer", cell_index: 0, tx_hash: m_nft_input_transaction.tx_hash, data: "0x00000000000000000000107b226e616d65223a22616c696365227d", type_hash: "0x")

    cell_input = ckb_transaction.cell_inputs.first
    cell_input.update(previous_output: { "tx_hash": m_nft_input_transaction.tx_hash, "index": "0" })
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash m_nft_info cell_index cell_type since).sort
    expected_m_nft_attributes = %i(issuer_name).sort
    expected_display_input = CkbUtils.hash_value_to_s(id: m_nft_cell_output.id, from_cellbase: false, capacity: m_nft_cell_output.capacity, address_hash: m_nft_cell_output.address_hash, generated_tx_hash: m_nft_cell_output.generated_by.tx_hash, cell_index: m_nft_cell_output.cell_index, cell_type: m_nft_cell_output.cell_type, m_nft_info: m_nft_cell_output.m_nft_info, since: {raw: "0x0000000000000000", median_timestamp: "0"})
    display_inputs = ckb_transaction.display_inputs
    assert_equal expected_attributes, display_inputs.first.keys.sort
    assert_equal expected_m_nft_attributes, display_inputs.first[:m_nft_info].keys.sort
    assert_equal expected_display_input, display_inputs.first
  end

  test "#display_inputs should contain m_nft_class info for m_nft_class transaction" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    m_nft_input_block = create(:block, :with_block_hash)
    m_nft_input_transaction = create(:ckb_transaction, block: m_nft_input_block)
    m_nft_cell_output = create(:cell_output, block: m_nft_input_block, ckb_transaction: m_nft_input_transaction, consumed_by: ckb_transaction, generated_by: m_nft_input_transaction, cell_type: "m_nft_class", cell_index: 0, tx_hash: m_nft_input_transaction.tx_hash, data: "0x00000003e800000000c000094669727374204e465400094669727374204e4654001768747470733a2f2f7878782e696d672e636f6d2f797979", type_hash: "0x")

    cell_input = ckb_transaction.cell_inputs.first
    cell_input.update(previous_output: { "tx_hash": m_nft_input_transaction.tx_hash, "index": "0" })
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash m_nft_info cell_index cell_type since).sort
    expected_m_nft_attributes = %i(class_name total).sort
    expected_display_input = CkbUtils.hash_value_to_s(id: m_nft_cell_output.id, from_cellbase: false, capacity: m_nft_cell_output.capacity, address_hash: m_nft_cell_output.address_hash, generated_tx_hash: m_nft_cell_output.generated_by.tx_hash, cell_index: m_nft_cell_output.cell_index, cell_type: m_nft_cell_output.cell_type, m_nft_info: m_nft_cell_output.m_nft_info,since: {raw: "0x0000000000000000", median_timestamp: "0"} )
    display_inputs = ckb_transaction.display_inputs
    assert_equal expected_attributes, display_inputs.first.keys.sort
    assert_equal expected_m_nft_attributes, display_inputs.first[:m_nft_info].keys.sort
    assert_equal expected_display_input, display_inputs.first
  end

  test "#display_inputs should contain m_nft_token info for m_nft_token transaction" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    m_nft_input_block = create(:block, :with_block_hash)
    m_nft_input_transaction = create(:ckb_transaction, block: m_nft_input_block)
    type_script = create(:type_script, code_hash: CkbSync::Api.instance.token_script_code_hash, hash_type: "type", args: "0x407c7ab0480a3ade9351e2107341dc99a1c111070000000500000004")
    m_nft_cell_output = create(:cell_output, block: m_nft_input_block, ckb_transaction: m_nft_input_transaction, consumed_by: ckb_transaction, generated_by: m_nft_input_transaction, cell_type: "m_nft_token", cell_index: 0, tx_hash: m_nft_input_transaction.tx_hash, data: "0x000000000000000000c000", type_hash: "0x", type_script_id: type_script.id)
    type_script1 = create(:type_script, code_hash: CkbSync::Api.instance.token_class_script_code_hash, hash_type: "type", args: "0x407c7ab0480a3ade9351e2107341dc99a1c1110700000005")
    m_nft_class_cell_output = create(:cell_output, block: m_nft_input_block, ckb_transaction: m_nft_input_transaction, consumed_by: ckb_transaction, generated_by: m_nft_input_transaction, cell_type: "m_nft_class", cell_index: 0, tx_hash: m_nft_input_transaction.tx_hash, data: "0x00000003e800000000c000094669727374204e465400094669727374204e4654001768747470733a2f2f7878782e696d672e636f6d2f797979", type_hash: "0x", type_script_id: type_script1.id)
    cell_input = ckb_transaction.cell_inputs.first
    cell_input.update(previous_output: { "tx_hash": m_nft_input_transaction.tx_hash, "index": "0" })
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash m_nft_info cell_index cell_type since).sort
    expected_m_nft_attributes = %i(class_name token_id total).sort
    expected_display_input = CkbUtils.hash_value_to_s(id: m_nft_cell_output.id, from_cellbase: false, capacity: m_nft_cell_output.capacity, address_hash: m_nft_cell_output.address_hash, generated_tx_hash: m_nft_cell_output.generated_by.tx_hash, cell_index: m_nft_cell_output.cell_index, cell_type: m_nft_cell_output.cell_type, m_nft_info: m_nft_cell_output.m_nft_info, since: {raw: "0x0000000000000000", median_timestamp: "0"} )
    display_inputs = ckb_transaction.display_inputs

    assert_equal expected_attributes, display_inputs.first.keys.sort
    assert_equal expected_m_nft_attributes, display_inputs.first[:m_nft_info].keys.sort
    assert_equal expected_display_input, display_inputs.first
  end

  test "#display_outputs should contain m_nft_issuer info for m_nft_issuer transaction" do
    m_nft_output_block = create(:block, :with_block_hash)
    m_nft_output_transaction = create(:ckb_transaction, block: m_nft_output_block)
    m_nft_cell_output = create(:cell_output, block: m_nft_output_block, ckb_transaction: m_nft_output_transaction, generated_by: m_nft_output_transaction, cell_type: "m_nft_issuer", cell_index: 0, tx_hash: m_nft_output_transaction.tx_hash, data: "0x00000000000000000000107b226e616d65223a22616c696365227d", type_hash: "0x")

    expected_attributes = %i(id capacity address_hash status consumed_tx_hash cell_type m_nft_info).sort
    expected_m_nft_attributes = %i(issuer_name).sort
    expected_display_output = CkbUtils.hash_value_to_s(id: m_nft_cell_output.id, capacity: m_nft_cell_output.capacity, address_hash: m_nft_cell_output.address_hash, status: m_nft_cell_output.status, consumed_tx_hash: nil, cell_type: m_nft_cell_output.cell_type, m_nft_info: m_nft_cell_output.m_nft_info)

    assert_equal expected_attributes, m_nft_output_transaction.display_outputs.first.keys.sort
    assert_equal expected_m_nft_attributes, m_nft_output_transaction.display_outputs.first[:m_nft_info].keys.sort
    assert_equal expected_display_output, m_nft_output_transaction.display_outputs.first
  end

  test "#display_outputs should contain m_nft_class info for m_nft_class transaction" do
    m_nft_output_block = create(:block, :with_block_hash)
    m_nft_output_transaction = create(:ckb_transaction, block: m_nft_output_block)
    m_nft_cell_output = create(:cell_output, block: m_nft_output_block, ckb_transaction: m_nft_output_transaction, generated_by: m_nft_output_transaction, cell_type: "m_nft_class", cell_index: 0, tx_hash: m_nft_output_transaction.tx_hash, data: "0x00000003e800000000c000094669727374204e465400094669727374204e4654001768747470733a2f2f7878782e696d672e636f6d2f797979", type_hash: "0x")

    expected_attributes = %i(id capacity address_hash status consumed_tx_hash cell_type m_nft_info).sort
    expected_m_nft_attributes = %i(class_name total).sort
    expected_display_output = CkbUtils.hash_value_to_s(id: m_nft_cell_output.id, capacity: m_nft_cell_output.capacity, address_hash: m_nft_cell_output.address_hash, status: m_nft_cell_output.status, consumed_tx_hash: nil, cell_type: m_nft_cell_output.cell_type, m_nft_info: m_nft_cell_output.m_nft_info)

    assert_equal expected_attributes, m_nft_output_transaction.display_outputs.first.keys.sort
    assert_equal expected_m_nft_attributes, m_nft_output_transaction.display_outputs.first[:m_nft_info].keys.sort
    assert_equal expected_display_output, m_nft_output_transaction.display_outputs.first
  end

  test "#display_outputs should contain m_nft_token info for m_nft_token transaction" do
    m_nft_output_block = create(:block, :with_block_hash)
    m_nft_output_transaction = create(:ckb_transaction, block: m_nft_output_block)
    type_script = create(:type_script, code_hash: CkbSync::Api.instance.token_script_code_hash, hash_type: "type", args: "0x407c7ab0480a3ade9351e2107341dc99a1c111070000000500000004")
    m_nft_cell_output = create(:cell_output, block: m_nft_output_block, ckb_transaction: m_nft_output_transaction, generated_by: m_nft_output_transaction, cell_type: "m_nft_token", cell_index: 0, tx_hash: m_nft_output_transaction.tx_hash, data: "0x000000000000000000c000", type_hash: "0x", type_script_id: type_script.id)
    type_script1 = create(:type_script, code_hash: CkbSync::Api.instance.token_class_script_code_hash, hash_type: "type", args: "0x407c7ab0480a3ade9351e2107341dc99a1c1110700000005")
    create(:cell_output, block: m_nft_output_block, ckb_transaction: m_nft_output_transaction, consumed_by: m_nft_output_transaction, generated_by: m_nft_output_transaction, cell_type: "m_nft_class", cell_index: 0, tx_hash: m_nft_output_transaction.tx_hash, data: "0x00000003e800000000c000094669727374204e465400094669727374204e4654001768747470733a2f2f7878782e696d672e636f6d2f797979", type_hash: "0x", type_script_id: type_script1.id)
    expected_attributes = %i(id capacity address_hash status consumed_tx_hash cell_type m_nft_info).sort
    expected_m_nft_attributes = %i(class_name token_id total).sort
    expected_display_output = CkbUtils.hash_value_to_s(id: m_nft_cell_output.id, capacity: m_nft_cell_output.capacity, address_hash: m_nft_cell_output.address_hash, status: m_nft_cell_output.status, consumed_tx_hash: nil, cell_type: m_nft_cell_output.cell_type, m_nft_info: m_nft_cell_output.m_nft_info)
    display_outputs = m_nft_output_transaction.display_outputs
    assert_equal expected_attributes, display_outputs.first.keys.sort
    assert_equal expected_m_nft_attributes, display_outputs.first[:m_nft_info].keys.sort
    assert_equal expected_display_output, display_outputs.first
  end

  test "#display_outputs should contain nrc_721_token info for nrc_721_token transaction" do
    nrc_721_token_output_block = create(:block, :with_block_hash)
    nrc_721_token_output_transaction = create(:ckb_transaction, block: nrc_721_token_output_block)

    nrc_factory_cell = create(:nrc_factory_cell, code_hash: "0x00000000000000000000000000000000000000000000000000545950455f4944013620e2ced53373c5b55c5cef79b7fd0a875c60a70382a9e9664fe28e0bb345ab22c70f8e24a90dcccc7eb1ea669ac6cfecab095a1886af01d71612fdb3c836c8", args: "0x3620e2ced53373c5b55c5cef79b7fd0a875c60a70382a9e9664fe28e0bb345ab", verified: true)
    nrc_721_factory_type_script = create(:type_script, code_hash: nrc_factory_cell.code_hash, hash_type: "type", args: nrc_factory_cell.args)
    nrc_721_factory_cell_output = create(:cell_output, block: nrc_721_token_output_block, ckb_transaction: nrc_721_token_output_transaction, generated_by: nrc_721_token_output_transaction, cell_type: "nrc_721_factory", cell_index: 1, tx_hash: nrc_721_token_output_transaction.tx_hash, data: "0x24ff5a9ab8c38d195ce2b4ea75ca8987000a47616d62697420317374000000156465762e6b6f6c6c6563742e6d652f746f6b656e73000000000000003c000000000000000000", type_hash: "0x", type_script_id: nrc_721_factory_type_script.id)

    nrc_721_token_type_script = create(:type_script, code_hash: "0x#{SecureRandom.hex(32)}", hash_type: "type", args: "0x00000000000000000000000000000000000000000000000000545950455f4944013620e2ced53373c5b55c5cef79b7fd0a875c60a70382a9e9664fe28e0bb345ab22c70f8e24a90dcccc7eb1ea669ac6cfecab095a1886af01d71612fdb3c836c8")
    nrc_721_token_cell_output = create(:cell_output, block: nrc_721_token_output_block, ckb_transaction: nrc_721_token_output_transaction, generated_by: nrc_721_token_output_transaction, cell_type: "nrc_721_token", cell_index: 0, tx_hash: nrc_721_token_output_transaction.tx_hash, data: "0x0ddeff3e8ee03cbf6a2c6920d05c381e", type_hash: "0x", type_script_id: nrc_721_token_type_script.id)
    udt = create(:udt, type_hash: nrc_721_token_cell_output.type_hash, udt_type: "nrc_721_token", nrc_factory_cell_id: nrc_factory_cell.id)
    address = create(:address)
    udt_account = create(:udt_account, udt: udt, address: address, nft_token_id: "22c70f8e24a90dcccc7eb1ea669ac6cfecab095a1886af01d71612fdb3c836c8")

    factory_info = { symbol: "TTF" }
    token_info = { symbol: "TTF", amount: udt_account.nft_token_id }
    display_outputs = nrc_721_token_output_transaction.display_outputs
    assert_equal factory_info.to_a, display_outputs.first[:nrc_721_token_info].to_a
    assert_equal token_info, display_outputs.last[:nrc_721_token_info]
  end

  test "#to_raw should return raw tx json structure" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    json = ckb_transaction.to_raw
    assert_equal %w(hash header_deps cell_deps inputs outputs outputs_data version witnesses).sort, json.keys.map(&:to_s).sort
  end
end
