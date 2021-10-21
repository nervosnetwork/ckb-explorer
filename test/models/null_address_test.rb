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

  test ".dao_deposit should return zero" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_equal 0, null_address.dao_deposit
  end

  test ".interest should return zero" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")
    assert_equal 0, null_address.interest
  end

  test ".lock_script should return LockScript" do
    ENV["CKB_NET_MODE"] = "mainnet"
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
    ENV["CKB_NET_MODE"] = "mainnet"
    null_address = NullAddress.new("ckt1qyq2cvlfef5kt043vcsy6rrt7snae2emda9spqvj6s")
    assert_raise Api::V1::Exceptions::AddressNotMatchEnvironmentError do
      null_address.lock_script
    end
  end

  test ".lock_info should return estimated lock info for valid address with since" do
    create(:block, :with_block_hash, epoch: 40, timestamp: 1576062594613)
    CkbSync::Api.any_instance.stubs(:get_tip_header).returns(
      CKB::Types::BlockHeader.new(
        compact_target: "0x1a29391f",
        hash: "0xc68b7a63e8b0ab82d7e13fe8c580e61d7c156d13d002f3283bf34fdbed5c0cb2",
        number: "0x36330",
        parent_hash: "0xff5b1f89d8672fed492ebb34be8b2f12ff6cdfb5347e41448d2710f8a7ba1517",
        nonce: "0x7f22eaf01000000000000002c14a3d1",
        timestamp: "0x16ef4a6ae35",
        transactions_root: "0x304b48778593f4aa6677298289e05b0764e94a1f84c7b771e34138849ceeec3f",
        proposals_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        extra_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        version: "0x0",
        epoch: "0x5590558000028",
        dao: "0x39375e92e46d1c2faf11706ba29d2300aca3fbd5ca6d1900004fe04913440007"
      )
    )
    null_address = NullAddress.new("ckt1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323k5v49yzmvm0q0kfqw0hk0kyal6z32nwjvcqqr7qyzq8yqtec2wj")
    expected_lock_info = { status: "locked", epoch_number: "51", epoch_index: "764", estimated_unlock_time: "1576226962613" }

    assert_equal expected_lock_info.to_a.sort, null_address.lock_info.to_a.sort
  end

  test ".lock_info should return real lock info for valid address with since" do
    create(:block, :with_block_hash, epoch: 51, timestamp: 1574684878790, start_number: 79276, number: 80040)
    CkbSync::Api.any_instance.stubs(:get_tip_header).returns(
      CKB::Types::BlockHeader.new(
        compact_target: "0x1a29391f",
        hash: "0xc68b7a63e8b0ab82d7e13fe8c580e61d7c156d13d002f3283bf34fdbed5c0cb2",
        number: "0x36330",
        parent_hash: "0xff5b1f89d8672fed492ebb34be8b2f12ff6cdfb5347e41448d2710f8a7ba1517",
        nonce: "0x7f22eaf01000000000000002c14a3d1",
        timestamp: "0x16ef4a6ae35",
        transactions_root: "0x304b48778593f4aa6677298289e05b0764e94a1f84c7b771e34138849ceeec3f",
        proposals_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        extra_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        version: "0x0",
        epoch: "0x5eb00a3000089",
        dao: "0x39375e92e46d1c2faf11706ba29d2300aca3fbd5ca6d1900004fe04913440007"
      )
    )
    null_address = NullAddress.new("ckt1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323k5v49yzmvm0q0kfqw0hk0kyal6z32nwjvcqqr7qyzq8yqtec2wj")
    expected_lock_info = { status: "unlocked", epoch_number: "51", epoch_index: "764", estimated_unlock_time: "1574684878790" }

    assert_equal expected_lock_info.to_a.sort, null_address.lock_info.to_a.sort
  end

  test ".lock_info should return nil for normal address" do
    null_address = NullAddress.new("ckb1qyqxfde320py026hwvsev240t35mjjvsccgq5dugeg")

    assert_nil null_address.lock_info
  end

  test "#cached_lock_script and lock_script should return the same value" do
    ENV["CKB_NET_MODE"] = "testnet"
    null_address = NullAddress.new("ckt1qyqvrwwyvnlk0mq5v8hrecc0raw58h8nanqq4ufmkm")
    assert_equal null_address.cached_lock_script, null_address.lock_script
    ENV["CKB_NET_MODE"] = "mainnet"
  end
end
