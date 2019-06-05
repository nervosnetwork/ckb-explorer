require "test_helper"

class LockScriptTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:cell_output)
    should belong_to(:address)
  end

  context "validations" do
    should validate_presence_of(:code_hash)
  end

  test "#code_hash should decodes packed string" do
    VCR.use_cassette("blocks/10") do
      SyncInfo.local_inauthentic_tip_block_number
      create(:sync_info, value: 10, name: "inauthentic_tip_block_number")
      node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
      CkbSync::Persist.save_block(node_block, "inauthentic")
      packed_block_hash = DEFAULT_NODE_BLOCK_HASH
      block = Block.find_by(block_hash: packed_block_hash)
      ckb_transaction = block.ckb_transactions.first
      cell_output = ckb_transaction.cell_outputs.first
      lock_script = cell_output.lock_script
      assert_equal unpack_attribute(lock_script, "code_hash"), lock_script.code_hash
    end
  end
end
