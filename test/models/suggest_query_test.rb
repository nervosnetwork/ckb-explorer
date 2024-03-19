require "test_helper"

class SuggestQueryTest < ActiveSupport::TestCase
  test "should raise error when address is invalid" do
    query_key = "ckc1q9gry5zg3pzs2q65ty0ylaf6c9er0hju5su49jdgry8n2c"

    assert_raises ActiveRecord::RecordNotFound do
      SuggestQuery.new(query_key).find!
    end
  end

  test "should return Block by query key when query key is a exist block number" do
    block = create(:block, number: 12)

    assert_equal BlockSerializer.new(block).serialized_json, SuggestQuery.new("12").find!.serialized_json
  end

  test "should return Block by query key when query key is a exist block hash" do
    block = create(:block, number: 12)

    assert_equal BlockSerializer.new(block).serialized_json, SuggestQuery.new(block.block_hash).find!.serialized_json
  end

  test "should return CkbTransaction by query key when query key is a exist tx hash" do
    tx = create(:ckb_transaction)

    assert_equal CkbTransactionSerializer.new(tx).serialized_json, SuggestQuery.new(tx.tx_hash).find!.serialized_json
  end

  test "should return Address by query key when query key is a exist address hash" do
    address = create(:address, :with_lock_script)
    address.query_address = address.address_hash

    assert_equal AddressSerializer.new(address).serialized_json,
                 SuggestQuery.new(address.address_hash).find!.serialized_json
  end

  test "should raise BlockNotFoundError when query key is a block number that doesn't exist" do
    create(:block, number: 12)
    assert_raises Api::V1::Exceptions::BlockNotFoundError do
      SuggestQuery.new("11").find!
    end
  end

  test "should return serialized NullAddress when query key is a address that doesn't exist" do
    ENV["CKB_NET_MODE"] = "testnet"
    create(:address, :with_lock_script)
    address = NullAddress.new("ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83")

    assert_equal AddressSerializer.new(address).serialized_json,
                 SuggestQuery.new("ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83").find!.serialized_json
    ENV["CKB_NET_MODE"] = "mainnet"
  end

  test "should return a udt when query key is a exist udt type hash" do
    udt = create(:udt, published: true)
    assert_equal UdtSerializer.new(udt).serialized_json, SuggestQuery.new(udt.type_hash).find!.serialized_json
  end

  test "should raise RecordNotFound error when target udt is not published" do
    udt = create(:udt)
    assert_raises ActiveRecord::RecordNotFound do
      SuggestQuery.new(udt.type_hash).find!
    end
  end

  test "should return lock script by code_hash" do
    ls = create(:lock_script)
    assert_equal LockScriptSerializer.new(ls).serialized_json, SuggestQuery.new(ls.code_hash).find!.serialized_json
  end

  test "should return type script by code_hash" do
    ts = create(:type_script)
    assert_equal TypeScriptSerializer.new(ts).serialized_json, SuggestQuery.new(ts.code_hash).find!.serialized_json
  end
end
