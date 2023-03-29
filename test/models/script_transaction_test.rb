require "test_helper"

class ScriptTransactionTest < ActiveSupport::TestCase
  setup do
    @contract = create :contract
    @block = create(:block, :with_block_hash)
    @script = create :script, contract_id: @contract.id
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block)
    @script_transaction = create :script_transaction, script_id: @script.id, ckb_transaction_id: @ckb_transaction.id
  end

  context "associations" do
    should belong_to(:script)
    should belong_to(:ckb_transaction)
  end

  test "it should create script_transaction" do
    assert_equal @ckb_transaction.id, @script_transaction.ckb_transaction_id
    assert_equal @script.id, @script_transaction.script_id
  end

  test "it should update script_transaction" do
    @script_transaction.update ckb_transaction_id: @ckb_transaction.id - 1, script_id: @script.id - 1
    assert_equal @ckb_transaction.id - 1, @script_transaction.ckb_transaction_id
    assert_equal @script.id - 1, @script_transaction.script_id
  end

  test "it should create_initial_data" do
    TypeScript.delete_all
    LockScript.delete_all
    Script.delete_all
    ScriptTransaction.delete_all
    Block.delete_all
    Contract.delete_all
    CellOutput.delete_all

    hash_type = 'type'
    code_hash = "0x1c04df09d9adede5bfc40ff1a39a3a17fc8e29f15c56f16b7e48680c600ee5ac"
    contract = create :contract, code_hash: code_hash, hash_type: hash_type
    block = create :block, :with_block_hash
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: block)
    CkbTransaction.where('id > ?', ckb_transaction.id).delete_all
    script = create :script
    type_script = create :type_script, code_hash: code_hash, hash_type: hash_type, script_id: script.id
    lock_script = create :lock_script, code_hash: code_hash, hash_type: hash_type, script_id: script.id
    cell_output = create :cell_output, :with_full_transaction, block_id: block.id
    cell_output.update lock_script_id: lock_script.id, type_script_id: type_script.id, ckb_transaction_id: ckb_transaction.id

    # for the 1st time, it will create
    ScriptTransaction.create_initial_data
    @script_transaction = ScriptTransaction.first
    assert_equal 1, ScriptTransaction.all.count
    assert_equal ckb_transaction.id, @script_transaction.ckb_transaction_id
    assert_equal script.id, @script_transaction.script_id

    # for the 2nd time, it should NOT create new record
    ScriptTransaction.create_initial_data
    assert_equal 1, ScriptTransaction.all.count
  end

end
