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

  test "#code_hash should decodes packed string" do
    VCR.use_cassette("blocks/10") do
      node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
      CkbSync::NodeDataProcessor.new.process_block(node_block)
      packed_block_hash = DEFAULT_NODE_BLOCK_HASH
      block = Block.find_by(block_hash: packed_block_hash)
      ckb_transaction = block.ckb_transactions.first
      assert_equal unpack_attribute(ckb_transaction, "tx_hash"), ckb_transaction.tx_hash
    end
  end
end
