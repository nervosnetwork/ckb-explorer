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
    assert_equal '0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f01855', @script.script_hash
  end

  test "update script" do
    @script.update is_contract: true, args: '0x441714e000fedf3247292c7f34fb16db14f49d9f1', script_hash: '0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f018551'
    assert_equal true, @script.is_contract
    assert_equal '0x441714e000fedf3247292c7f34fb16db14f49d9f1', @script.args
    assert_equal '0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f018551', @script.script_hash
  end

  test "it should create_initial_data, type_script only " do

    Contract.delete_all
    TypeScript.delete_all
    LockScript.delete_all
    Script.delete_all

    hash_type = 'type'
    code_hash = "0x#{SecureRandom.hex(64)}"
    contract = create :contract, code_hash: code_hash, hash_type: hash_type
    type_script = create :type_script, code_hash: code_hash, hash_type: hash_type

    # for the 1st time, it will create
    Script.create_initial_data
    @scripts = Script.all
    assert_equal 1, Script.all.count
    assert_equal type_script.args, @scripts.first.args
    assert_equal type_script.script_hash, @scripts.first.script_hash

    # for the 2nd time, it should NOT create new record
    Script.create_initial_data
    assert_equal 1, Script.all.count
  end

  test "it should create_initial_data, lock_script only " do
    Contract.delete_all
    TypeScript.delete_all
    LockScript.delete_all
    Script.delete_all

    hash_type = 'type'
    code_hash = "0x#{SecureRandom.hex(64)}"
    contract = create :contract, code_hash: code_hash, hash_type: hash_type
    lock_script = create :lock_script, code_hash: code_hash, hash_type: hash_type

    # for the 1st time, it will create
    Script.create_initial_data
    @scripts = Script.all
    assert_equal 1, Script.all.count
    assert_equal lock_script.args, @scripts.first.args
    assert_equal lock_script.script_hash, @scripts.first.script_hash

    # for the 2nd time, it should NOT create new record
    Script.create_initial_data
    assert_equal 1, Script.all.count
  end
end
