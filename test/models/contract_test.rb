require "test_helper"

class ContractTest < ActiveSupport::TestCase
  setup do
    @contract = create :contract, verified: false, hash_type: "type", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8", role: "type_script"
  end

  context "associations" do
    should have_many(:referring_cells)
    should have_many(:deployed_cells)
    should have_many(:scripts)
    should have_many(:ckb_transactions)
    should have_many(:cell_dependencies)
  end

  test "it should create contract" do
    assert_equal false, @contract.verified
    assert_equal false, @contract.deprecated
    assert_equal "type", @contract.hash_type
    assert_equal "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8", @contract.code_hash
    assert_equal "type_script", @contract.role
    assert_equal "SECP256K1/multisig (Source Code) is a script which allows a group of users to sign a single transaction.", @contract.description
    assert_equal "CKB COIN TEST", @contract.name
    assert_equal "TTF", @contract.symbol
  end

  test "it should update contract" do
    @contract.update deprecated: true, verified: true, hash_type: 'type1', code_hash: '0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a81', name: 'CKB COIN TEST1', role: 'lock_script', symbol: 'TTF1', deployed_args: '0x284c65a608e8e280aaa9c119a1a8fe0463a171511', description: 'Source Code is a script which allows a group of users to sign a single transaction.'
    assert_equal true, @contract.verified
    assert_equal true, @contract.deprecated
    assert_equal "type1", @contract.hash_type
    assert_equal "0x284c65a608e8e280aaa9c119a1a8fe0463a171511", @contract.deployed_args
    assert_equal "lock_script", @contract.role
    assert_equal "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a81", @contract.code_hash
    assert_equal "Source Code is a script which allows a group of users to sign a single transaction.", @contract.description
    assert_equal "CKB COIN TEST1", @contract.name
    assert_equal "TTF1", @contract.symbol
  end
  test "it should create initial data" do
    Script.delete_all
    LockScript.delete_all
    TypeScript.delete_all
    create :lock_script
    create :type_script
    Script.create_initial_data
    Contract.create_initial_data
    assert_equal 3, Contract.count
  end

end
