require "test_helper"

class ScriptTest < ActiveSupport::TestCase
  setup do
    @script = create :script
    # create for @cell_dependency
    @block = create :block, :with_block_hash
    @ckb_transaction = create :ckb_transaction, :with_multiple_inputs_and_outputs, block: @block
    @cell_output = create :cell_output, :with_full_transaction, block: @block
    @cell_dependency = create :cell_dependency, ckb_transaction_id: @ckb_transaction.id, contract_cell_id: @cell_output.id,
                                                script_id: @script.id
  end

  context "associations" do
    should have_many(:type_scripts)
    should have_many(:cell_dependencies)
    should have_many(:ckb_transactions)
    should have_many(:lock_scripts)
    should have_many(:script_transactions)
  end

  test "create script" do
    assert_equal false, @script.is_contract
    assert_equal "0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f01855", @script.script_hash
  end

  test "update script" do
    @script.update is_contract: true, args: "0x441714e000fedf3247292c7f34fb16db14f49d9f1", script_hash: "0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f018551"
    assert_equal true, @script.is_contract
    assert_equal "0x441714e000fedf3247292c7f34fb16db14f49d9f1", @script.args
    assert_equal "0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f018551", @script.script_hash
  end
end
