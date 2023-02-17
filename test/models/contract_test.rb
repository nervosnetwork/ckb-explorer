require "test_helper"

class ContractTest < ActiveSupport::TestCase
  setup do
    @contract = create :contract
    @block = create(:block, :with_block_hash)
    @script = create :script, contract_id: @contract.id
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block)
    @cell_output = create :cell_output, :with_full_transaction, block: @block
    @deployed_cell = create :deployed_cell, contract_id: @contract.id, cell_output_id: @cell_output.id
    @cell_dependency = create :cell_dependency, contract_id: @contract.id, ckb_transaction_id: @ckb_transaction.id, contract_cell_id: @cell_output.id
  end

  context "associations" do
    should have_many(:referring_cells)
    should have_many(:deployed_cells)
  end

  test "it should create contract" do
    assert_equal false, @contract.verified
    assert_equal 'type', @contract.hash_type
    assert_equal '0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8', @contract.code_hash
    assert_equal 'type_script', @contract.role
    assert_equal 'SECP256K1/multisig (Source Code) is a script which allows a group of users to sign a single transaction.', @contract.description
    assert_equal 'CKB COIN TEST', @contract.name
    assert_equal 'TTF', @contract.symbol
  end

  test "it should update contract" do
    @contract.update verified: true, hash_type: 'type1', code_hash: '0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a81', name: 'CKB COIN TEST1', role: 'lock_script', symbol: 'TTF1', deployed_args: '0x284c65a608e8e280aaa9c119a1a8fe0463a171511', description: 'Source Code is a script which allows a group of users to sign a single transaction.'
    assert_equal true, @contract.verified
    assert_equal 'type1', @contract.hash_type
    assert_equal '0x284c65a608e8e280aaa9c119a1a8fe0463a171511', @contract.deployed_args
    assert_equal 'lock_script', @contract.role
    assert_equal '0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a81', @contract.code_hash
    assert_equal 'Source Code is a script which allows a group of users to sign a single transaction.', @contract.description
    assert_equal 'CKB COIN TEST1', @contract.name
    assert_equal 'TTF1', @contract.symbol
  end

  test "it should has_many cell_dependencies scripts, and deployed_cells" do
    assert_equal @cell_dependency, @contract.cell_dependencies.first
    assert_equal @deployed_cell, @contract.deployed_cells.first
    assert_equal @script, @contract.scripts.first
  end

end
