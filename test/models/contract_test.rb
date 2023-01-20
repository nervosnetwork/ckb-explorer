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
    assert_equal 'owner', contract.role
    assert_equal 'CKB COIN TEST', contract.name
    assert_equal 'TTF', contract.symbol
  end

  test "update contract" do
    contract = create :contract
    contract.update verified: true, hash_type: 'type1', name: 'CKB COIN TEST1', role: 'owner1', symbol: 'TTF1', deployed_args: '0x284c65a608e8e280aaa9c119a1a8fe0463a171511'
    assert_equal true, contract.verified
    assert_equal 'type1', contract.hash_type
    assert_equal '0x284c65a608e8e280aaa9c119a1a8fe0463a171511', contract.deployed_args
    assert_equal 'owner1', contract.role
    assert_equal 'CKB COIN TEST1', contract.name
    assert_equal 'TTF1', contract.symbol
  end

end
