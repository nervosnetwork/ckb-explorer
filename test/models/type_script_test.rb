require "test_helper"

class TypeScriptTest < ActiveSupport::TestCase
  setup do
    create(:table_record_count, :block_counter)
    create(:table_record_count, :ckb_transactions_counter)
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
  end

  context "associations" do
    should belong_to(:cell_output).optional
  end

  context "validations" do
    should validate_presence_of(:code_hash)
  end

  test "#code_hash should decodes packed string" do
    GenerateStatisticsDataWorker.any_instance.stubs(:perform).returns(true)
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
      CKB::Types::Epoch.new(
        compact_target: "0x1000",
        length: "0x07d0",
        number: "0x0",
        start_number: "0x0"
      )
    )
    CkbSync::Api.any_instance.stubs(:get_block_cycles).returns(
      [
        "0x100", "0x200", "0x300", "0x400", "0x500", "0x600", "0x700", "0x800", "0x900"
      ]
    )
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      create(:block, :with_block_hash, number: node_block.header.number - 1)

      CkbSync::NewNodeDataProcessor.new.process_block(node_block)
      block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      ckb_transaction = block.ckb_transactions.first
      cell_output = ckb_transaction.cell_outputs.first
      type_script = cell_output.type_script
      lock_script = cell_output.lock_script
      if type_script.blank?
        type_script = TypeScript.create(
          args: lock_script.args,
          code_hash: lock_script.code_hash
        )
        cell_output.update(type_script_id: type_script.id)
      else
        type_script = cell_output.type_script
      end
      assert_equal unpack_attribute(type_script, "code_hash"), type_script.code_hash
    end
  end

  test "#to_node should return correct hash" do
    cell_output = create_cell_output
    type_script = cell_output.type_script
    node_type = { args: type_script.args, code_hash: type_script.code_hash, hash_type: type_script.hash_type }

    assert_equal node_type, type_script.to_node
  end
end
