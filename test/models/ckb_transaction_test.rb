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
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      CkbSync::NodeDataProcessor.new.process_block(node_block)
      block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      ckb_transaction = block.ckb_transactions.first
      assert_equal unpack_attribute(ckb_transaction, "tx_hash"), ckb_transaction.tx_hash
    end
  end
end
