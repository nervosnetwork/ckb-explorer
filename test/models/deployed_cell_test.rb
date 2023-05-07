require "test_helper"

class DeployedCellTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:contract)
    should belong_to(:cell_output)
  end

  setup do
    @block = create :block, :with_block_hash
    @ckb_transaction = create :ckb_transaction, :with_multiple_inputs_and_outputs, block_id: @block.id

    code_hash = "0x671ddda336db68ce0daebde885f44e2f46406d6c838484b4bd8934173e518876"
    @cell_output = create :cell_output, :with_full_transaction, ckb_transaction_id: @ckb_transaction.id, block: @block,
                                                                data: "0x", data_hash: code_hash
    @contract = create :contract
    @deployed_cell = create :deployed_cell, contract_id: @contract.id, cell_output_id: @cell_output.id
    CellOutput.stubs(:find_by_pointer).returns(@cell_output)
    CellOutput.any_instance.stubs(:data_hash).returns(code_hash)
    CellOutput.any_instance.stubs(:type_hash).returns(code_hash)
  end

  test "it should create deployed_cell" do
    assert_equal @cell_output.id, @deployed_cell.cell_output_id
    assert_equal @contract.id, @deployed_cell.contract_id
  end

  test "it should create_initial_data_for_ckb_transaction for cell_outputs when hash_type is type" do
    # step 1 delete redundant data
    delete_redundant_data

    # step 2 prepare test data
    prepare_test_data_for_hash_type_for_cell_outputs

    # step 3 start unit test
    # for the 1st time, it will create
    DeployedCell.create_initial_data_for_ckb_transaction @ckb_transaction_with_cell_deps, @cell_deps
    @deployed_cell = DeployedCell.first
    contract_id = @ckb_transaction_with_cell_deps.cell_outputs.first.lock_script.script.contract_id
    assert_equal 1, DeployedCell.all.count
    assert_equal contract_id, @deployed_cell.contract_id

    # for the 2nd time, it should NOT create record
    DeployedCell.create_initial_data_for_ckb_transaction @ckb_transaction_with_cell_deps, @cell_deps
    assert_equal 1, DeployedCell.all.count
  end

  test "it should create_initial_data_for_ckb_transaction for cell_outputs when hash_type is data" do
    # step 1 delete redundant data
    delete_redundant_data
    # step 2 prepare test data
    prepare_test_data_for_hash_type_for_cell_outputs hash_type: "data"
    # step 3 start unit test
    # for the 1st time, it will create
    DeployedCell.create_initial_data_for_ckb_transaction @ckb_transaction_with_cell_deps, @cell_deps
    @deployed_cell = DeployedCell.first
    contract_id = @ckb_transaction_with_cell_deps.cell_outputs.first.lock_script.script.contract_id
    assert_equal 1, DeployedCell.all.count
    assert_equal contract_id, @deployed_cell.contract_id

    # for the 2nd time, it should NOT create record
    # DeployedCell.create_initial_data_for_ckb_transaction @ckb_transaction_with_cell_deps
    assert_equal 1, DeployedCell.all.count
  end

  test "it should create_initial_data_for_ckb_transaction for cell_inputs when hash_type is type" do
    # step 1 delete redundant data
    delete_redundant_data

    # step 2 prepare test data
    prepare_test_data_for_hash_type_for_cell_inputs

    # step 3 start unit test
    # for the 1st time, it will create
    # DeployedCell.create_initial_data_for_ckb_transaction @ckb_transaction_with_cell_deps
    @deployed_cell = DeployedCell.first
    contract_id = @ckb_transaction_with_cell_deps.cell_inputs.first.previous_cell_output.lock_script.script.contract_id
    assert_equal contract_id, @deployed_cell.contract_id
    assert_equal 1, DeployedCell.all.count

    # for the 2nd time, it should NOT create record
    DeployedCell.create_initial_data_for_ckb_transaction @ckb_transaction_with_cell_deps, @cell_deps
    assert_equal 1, DeployedCell.all.count
  end

  test "it should create_initial_data_for_ckb_transaction for cell_inputs when hash_type is data" do
    # step 1 delete redundant data
    delete_redundant_data
    # step 2 prepare test data
    prepare_test_data_for_hash_type_for_cell_inputs hash_type: "data"
    # step 3 start unit test
    # for the 1st time, it will create
    # DeployedCell.create_initial_data_for_ckb_transaction @ckb_transaction_with_cell_deps, @cell_deps
    @deployed_cell = DeployedCell.first
    contract_id = @ckb_transaction_with_cell_deps.cell_inputs.first.previous_cell_output.lock_script.script.contract_id
    assert_equal contract_id, @deployed_cell.contract_id
    assert_equal 1, DeployedCell.all.count

    # for the 2nd time, it should NOT create record
    DeployedCell.create_initial_data_for_ckb_transaction @ckb_transaction_with_cell_deps, @cell_deps
    assert_equal 1, DeployedCell.all.count
  end

  private

  def delete_redundant_data
    Script.delete_all
    ScriptTransaction.delete_all
    Contract.delete_all
    DeployedCell.delete_all
    CkbTransaction.delete_all
    Block.delete_all
  end

  def prepare_test_data_for_hash_type_for_cell_outputs(hash_type: "type")
    @contract = create :contract, hash_type: hash_type
    # CKB::Blake2b.hexdigest('0x010200000000008d01f3')
    @deployed_cell = @contract.deployed_cells.first
    code_hash = @contract.code_hash
    tx_hash = @deployed_cell.cell_output.ckb_transaction.tx_hash
    cell_deps = @cell_deps = [
      {
        "dep_type" => "code",
        "out_point" => {
          "index" => @deployed_cell.cell_output.cell_index,
          "tx_hash" => tx_hash } }
    ]

    block = create :block, :with_block_hash
    @ckb_transaction_with_cell_deps = create :ckb_transaction, block: block, cell_deps: cell_deps
    CkbTransaction.where("id < ?", @ckb_transaction_with_cell_deps.id).delete_all
    script = create :script, contract_id: @contract.id, is_contract: true
    type_script = create :type_script, code_hash: code_hash, hash_type: hash_type, script: script
    lock_script = create :lock_script, code_hash: code_hash, hash_type: hash_type, script: script
    # create test data: cell_outputs
    cell_output = create :cell_output, block: block, ckb_transaction: @ckb_transaction_with_cell_deps,
                                       lock_script: lock_script, type_script: type_script
  end

  def prepare_test_data_for_hash_type_for_cell_inputs(hash_type: "type")
    @contract = create :contract, hash_type: hash_type
    @deployed_cell = @contract.deployed_cells.first
    code_hash = @contract.code_hash
    tx_hash = @deployed_cell.cell_output.ckb_transaction.tx_hash
    cell_deps = @cell_deps = [
      {
        "dep_type" => "code",
        "out_point" => {
          "index" => @deployed_cell.cell_output.cell_index,
          "tx_hash" => tx_hash } }
    ]

    block = create :block, :with_block_hash
    @ckb_transaction_with_cell_deps = create :ckb_transaction, block: block, cell_deps: cell_deps
    CkbTransaction.where("id < ?", @ckb_transaction_with_cell_deps.id).delete_all
    script = create :script, contract_id: @contract.id, is_contract: true
    type_script = create :type_script, code_hash: code_hash, hash_type: hash_type, script_id: script.id
    lock_script = create :lock_script, code_hash: code_hash, hash_type: hash_type, script_id: script.id
    # create test data: cell_outputs
    cell_output = create :cell_output, block: block, ckb_transaction: @ckb_transaction_with_cell_deps,
                                       lock_script: lock_script, type_script: type_script
    temp_ckb_transaction = CkbTransaction.first
    temp_ckb_transaction.update tx_hash: tx_hash
    temp_cell_output = create :cell_output, :with_full_transaction, block: block, ckb_transaction: temp_ckb_transaction
    temp_cell_output.lock_script.update script_id: script.id

    cell_input = create :cell_input, :with_full_transaction, block: block,
                                                             ckb_transaction: @ckb_transaction_with_cell_deps
    cell_input.update ckb_transaction_id: @ckb_transaction_with_cell_deps.id, previous_cell_output_id: cell_output.id
    cell_input.previous_cell_output.lock_script.update script_id: script.id
  end
end
