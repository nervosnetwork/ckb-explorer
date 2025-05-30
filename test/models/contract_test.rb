require "test_helper"

class ContractTest < ActiveSupport::TestCase
  setup do
    @contract = create :contract, verified: false, hash_type: "type", type_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8", is_type_script: true
  end

  test "it should create contract" do
    assert_equal false, @contract.verified
    assert_equal false, @contract.deprecated
    assert_equal "type", @contract.hash_type
    assert_equal "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8", @contract.type_hash
    assert_equal true, @contract.is_type_script
    assert_equal "SECP256K1/multisig (Source Code) is a script which allows a group of users to sign a single transaction.", @contract.description
    assert_equal "CKB COIN TEST", @contract.name
  end

  test "it should update contract" do
    @contract.update deprecated: true, verified: true, hash_type: "type1", type_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a81", name: "CKB COIN TEST1",
                     is_lock_script: true, deployed_args: "0x284c65a608e8e280aaa9c119a1a8fe0463a171511", description: "Source Code is a script which allows a group of users to sign a single transaction."
    assert_equal true, @contract.verified
    assert_equal true, @contract.deprecated
    assert_equal "type1", @contract.hash_type
    assert_equal "0x284c65a608e8e280aaa9c119a1a8fe0463a171511", @contract.deployed_args
    assert_equal true, @contract.is_lock_script
    assert_equal "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a81", @contract.type_hash
    assert_equal "Source Code is a script which allows a group of users to sign a single transaction.", @contract.description
    assert_equal "CKB COIN TEST1", @contract.name
  end
end
