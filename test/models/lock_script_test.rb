require "test_helper"

class LockScriptTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:address)
  end

  context "validations" do
    should validate_presence_of(:code_hash)
  end

  test "#code_hash should decodes packed string" do
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      CkbSync::NodeDataProcessor.new.process_block(node_block)
      block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      ckb_transaction = block.ckb_transactions.first
      cell_output = ckb_transaction.cell_outputs.first
      lock_script = cell_output.lock_script
      assert_equal unpack_attribute(lock_script, "code_hash"), lock_script.code_hash
    end
  end
end
