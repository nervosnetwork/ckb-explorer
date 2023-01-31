require "test_helper"

class ContractTest < ActiveSupport::TestCase
  setup do
    create :contract
  end

  test "create contract" do
    contract = create :contract
    assert_equal false, contract.verified
    assert_equal 'type', contract.hash_type
    assert_equal '0x284c65a608e8e280aaa9c119a1a8fe0463a17151', contract.deployed_args
    assert_equal '0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8', contract.code_hash
    assert_equal 'type_script', contract.role
    assert_equal 'SECP256K1/multisig (Source Code) is a script which allows a group of users to sign a single transaction.', contract.description
    assert_equal 'CKB COIN TEST', contract.name
    assert_equal 'TTF', contract.symbol
  end

  test "update contract" do
    contract = create :contract
    contract.update verified: true, hash_type: 'type1', code_hash: '0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a81', name: 'CKB COIN TEST1', role: 'lock_script', symbol: 'TTF1', deployed_args: '0x284c65a608e8e280aaa9c119a1a8fe0463a171511', description: 'Source Code is a script which allows a group of users to sign a single transaction.'
    assert_equal true, contract.verified
    assert_equal 'type1', contract.hash_type
    assert_equal '0x284c65a608e8e280aaa9c119a1a8fe0463a171511', contract.deployed_args
    assert_equal 'lock_script', contract.role
    assert_equal '0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a81', contract.code_hash
    assert_equal 'Source Code is a script which allows a group of users to sign a single transaction.', contract.description
    assert_equal 'CKB COIN TEST1', contract.name
    assert_equal 'TTF1', contract.symbol
  end

end
