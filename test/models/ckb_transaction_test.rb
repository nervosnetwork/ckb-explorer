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
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
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
end
