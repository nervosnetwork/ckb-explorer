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
    expected_attributes = %i(id from_cellbase capacity address_hash generated_tx_hash)

    assert_equal [expected_attributes], ckb_transaction.display_inputs.map(&:keys).uniq
  end

  test "#display_inputs should contain correct attributes for cellbase" do
    ckb_transaction = create(:ckb_transaction, :with_single_output, is_cellbase: true)
    expected_attributes = %i(id from_cellbase capacity address_hash target_block_number generated_tx_hash)

    assert_equal [expected_attributes], ckb_transaction.display_inputs.map(&:keys).uniq
  end

  test "#display_outputs should contain correct attributes for normal transaction" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    expected_attributes = %i(id capacity address_hash status consumed_tx_hash)

    assert_equal [expected_attributes], ckb_transaction.display_outputs.map(&:keys).uniq
  end

  test "#display_outputs should contain correct attributes for cellbase" do
    ckb_transaction = create(:ckb_transaction, :with_single_output, is_cellbase: true)
    expected_attributes = %i(id capacity address_hash target_block_number base_reward commit_reward proposal_reward secondary_reward status consumed_tx_hash)

    assert_equal [expected_attributes], ckb_transaction.display_outputs.map(&:keys).uniq
  end

  test "#display_inputs should return correct generated_tx_hash" do
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs)
    expected_tx_hash = ckb_transaction.cell_inputs.first.previous_cell_output.generated_by.tx_hash

    assert_equal [expected_tx_hash], ckb_transaction.display_inputs.pluck(:generated_tx_hash).uniq
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
end
