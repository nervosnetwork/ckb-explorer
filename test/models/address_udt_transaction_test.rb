require "test_helper"

class AddressUdtTransactionTest < ActiveSupport::TestCase
  setup do
    @block = create(:block, :with_block_hash)
    @address = create :address
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block, udt_address_ids: [@address.id, @address.id + 1])
    @address_udt_transaction = create :address_udt_transaction, ckb_transaction_id: @ckb_transaction.id, address_id: @ckb_transaction.udt_address_ids.first
  end

  test "it should create address_udt_transaction" do
    assert_equal @ckb_transaction.id, @address_udt_transaction.ckb_transaction_id
    assert_equal @ckb_transaction.udt_address_ids.first, @address_udt_transaction.address_id
    assert_equal @address.id, @address_udt_transaction.address_id
  end

  test "it should create initial data" do
    CkbTransaction.delete_all
    AddressUdtTransaction.delete_all
    block = create(:block, :with_block_hash)
    address = create :address
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block, udt_address_ids: [address.id, address.id + 1])

    CkbTransaction.migrate_udt_address_ids
    assert_equal ckb_transaction.contained_udt_addresses.size, AddressUdtTransaction.count
    assert_equal ckb_transaction.id, AddressUdtTransaction.first.ckb_transaction_id
  end
end
