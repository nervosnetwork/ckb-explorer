require "test_helper"

class NullAddressTest < ActiveSupport::TestCase
  test ".id should return zero" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_equal 0, null_address.id
  end

  test ".balance should return zero" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_equal 0, null_address.balance
  end

  test ".ckb_transactions_count should return zero" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_equal 0, null_address.ckb_transactions_count
  end

  test ".lock_hash should return nil" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_nil null_address.lock_hash
  end

  test ".lock_info should return nil" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_nil null_address.lock_info
  end

  test ".cached_lock_script should return nil" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_nil null_address.cached_lock_script
  end

  test ".pending_reward_blocks_count should return zero" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_equal 0, null_address.pending_reward_blocks_count
  end

  test ".dao_deposit should return zero" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_equal 0, null_address.dao_deposit
  end

  test ".interest should return zero" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_equal 0, null_address.interest
  end

  test ".lock_script should return LockScript" do
    address_hash = "ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg"
    null_address = NullAddress.new(address_hash)
    script = CKB::AddressParser.new(address_hash).parse.script
    assert_equal script.code_hash, null_address.lock_script.code_hash
    assert_equal script.args, null_address.lock_script.args
    assert_equal script.hash_type, null_address.lock_script.hash_type
  end

  test ".lock_script should raise AddressNotMatchEnvironmentError when address does not match the testnet" do
    ENV["CKB_NET_MODE"] = "testnet"
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_raise Api::V1::Exceptions::AddressNotMatchEnvironmentError do
      null_address.lock_script
    end
    ENV["CKB_NET_MODE"] = "mainnet"
  end

  test ".lock_script should raise AddressNotMatchEnvironmentError when address does not match the mainnet" do
    null_address = NullAddress.new("ckt1qyq2cvlfef5kt043vcsy6rrt7snae2emda9spqvj6s")
    assert_raise Api::V1::Exceptions::AddressNotMatchEnvironmentError do
      null_address.lock_script
    end
  end
end
