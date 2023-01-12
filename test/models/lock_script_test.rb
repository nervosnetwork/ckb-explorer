require "test_helper"

class LockScriptTest < ActiveSupport::TestCase
  setup do
    create(:table_record_count, :block_counter)
    create(:table_record_count, :ckb_transactions_counter)
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
    GenerateStatisticsDataWorker.any_instance.stubs(:perform).returns(true)
    CkbSync::Api.any_instance.stubs(:get_block_cycles).returns(
      [
        "0x100", "0x200", "0x300", "0x400", "0x500", "0x600", "0x700", "0x800", "0x900"
      ]
    )
  end

  context "validations" do
    should validate_presence_of(:code_hash)
  end

  test "#code_hash should decodes packed string" do
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
      cell_output = ckb_transaction.cell_outputs.first
      lock_script = cell_output.lock_script
      assert_equal unpack_attribute(lock_script, "code_hash"), lock_script.code_hash
    end
  end

  test "#lock_info should return nil when code hash is not secp multisig cell type hash" do
    CkbSync::Api.any_instance.stubs(:get_tip_header).returns(
      CKB::Types::BlockHeader.new(
        compact_target: "0x1a29391f",
        hash: "0xc68b7a63e8b0ab82d7e13fe8c580e61d7c156d13d002f3283bf34fdbed5c0cb2",
        number: "0x36330",
        parent_hash: "0xff5b1f89d8672fed492ebb34be8b2f12ff6cdfb5347e41448d2710f8a7ba1517",
        nonce: "0x7f22eaf01000000000000002c14a3d1",
        timestamp: "0x16ef4a6ae35",
        transactions_root: "0x304b48778593f4aa6677298289e05b0764e94a1f84c7b771e34138849ceeec3f",
        proposals_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        extra_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        version: "0x0",
        epoch: "0x5eb00a3000089",
        dao: "0x39375e92e46d1c2faf11706ba29d2300aca3fbd5ca6d1900004fe04913440007"
      )
    )
    address = create(:address)
    lock_script = create(:lock_script, address: address, args: "0xda648442dbb7347e467d1d09da13e5cd3a0ef0e1", code_hash: "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8")

    assert_nil lock_script.lock_info
  end

  test "#lock_info should return nil when args size is not equal to 28" do
    CkbSync::Api.any_instance.stubs(:get_tip_header).returns(
      CKB::Types::BlockHeader.new(
        compact_target: "0x1a29391f",
        hash: "0xc68b7a63e8b0ab82d7e13fe8c580e61d7c156d13d002f3283bf34fdbed5c0cb2",
        number: "0x36330",
        parent_hash: "0xff5b1f89d8672fed492ebb34be8b2f12ff6cdfb5347e41448d2710f8a7ba1517",
        nonce: "0x7f22eaf01000000000000002c14a3d1",
        timestamp: "0x16ef4a6ae35",
        transactions_root: "0x304b48778593f4aa6677298289e05b0764e94a1f84c7b771e34138849ceeec3f",
        proposals_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        extra_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        version: "0x0",
        epoch: "0x317025a000077",
        dao: "0x39375e92e46d1c2faf11706ba29d2300aca3fbd5ca6d1900004fe04913440007"
      )
    )
    address = create(:address)
    lock_script = create(:lock_script, address: address, args: "0xda648442dbb7347e467d1d09da13e5cd3a0ef0e1", code_hash: Settings.secp_multisig_cell_type_hash)

    assert_nil lock_script.lock_info
  end

  test "#lock_info should return specific unlock time when since index is larger than epoch length" do
    CkbSync::Api.any_instance.stubs(:get_tip_header).returns(
      CKB::Types::BlockHeader.new(
        compact_target: "0x1a29391f",
        hash: "0xc68b7a63e8b0ab82d7e13fe8c580e61d7c156d13d002f3283bf34fdbed5c0cb2",
        number: "0x1a4cd",
        parent_hash: "0xff5b1f89d8672fed492ebb34be8b2f12ff6cdfb5347e41448d2710f8a7ba1517",
        nonce: "0x7f22eaf01000000000000002c14a3d1",
        timestamp: "0x16ef4a6ae35",
        transactions_root: "0x304b48778593f4aa6677298289e05b0764e94a1f84c7b771e34138849ceeec3f",
        proposals_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        extra_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        version: "0x0",
        epoch: "0x317025a000077",
        dao: "0x39375e92e46d1c2faf11706ba29d2300aca3fbd5ca6d1900004fe04913440007"
      )
    )
    address = create(:address)
    create(:block, number: 107036, start_number: 106327, epoch: 118, timestamp: 1576648516881, length: 796)
    lock_script = create(:lock_script, address: address, args: "0x691fdcdc80ca82a4cb15826dcb7f0cf04cd821367600004506080720", code_hash: Settings.secp_multisig_cell_type_hash)
    expected_lock_info = { status: "locked", epoch_number: "118", epoch_index: "1605", estimated_unlock_time: "1576648532881" }

    assert_equal expected_lock_info, lock_script.lock_info
  end
end
