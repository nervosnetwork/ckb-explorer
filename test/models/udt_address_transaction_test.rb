require "test_helper"

class UdtAddressTransactionTest < ActiveSupport::TestCase
  setup do
    @block = create(:block, :with_block_hash)
    @address = create :address
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block, udt_address_ids: [@address.id, @address.id + 1])
    @udt_address_transaction = create :udt_address_transaction, ckb_transaction_id: @ckb_transaction.id, udt_address_id: @ckb_transaction.udt_address_ids.first
  end

  context "associations" do
    should belong_to(:ckb_transaction)
    should belong_to(:address)
  end

  test "it should create udt_address_transaction" do
    assert_equal @ckb_transaction.id, @udt_address_transaction.ckb_transaction_id
    assert_equal @ckb_transaction.udt_address_ids.first, @udt_address_transaction.udt_address_id
    assert_equal @address.id, @udt_address_transaction.udt_address_id
  end

  test "it should create initial data" do
    CkbTransaction.delete_all
    UdtAddressTransaction.delete_all
    block = create(:block, :with_block_hash)
    address = create :address
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block, udt_address_ids: [address.id, address.id + 1])

    # for the 1st time, it will create
    UdtAddressTransaction.create_initial_data CkbTransaction.all
    assert_equal ckb_transaction.udt_address_ids.size, UdtAddressTransaction.count
    assert_equal ckb_transaction.id, UdtAddressTransaction.first.ckb_transaction_id
    assert_equal ckb_transaction.id, UdtAddressTransaction.last.ckb_transaction_id
    assert_equal ckb_transaction.udt_address_ids, UdtAddressTransaction.all.map{|e| e.udt_address_id}

    # for the 2nd time, it should NOT create new record
    UdtAddressTransaction.create_initial_data CkbTransaction.all
    assert_equal ckb_transaction.udt_address_ids.size, UdtAddressTransaction.count
    assert_equal ckb_transaction.id, UdtAddressTransaction.first.ckb_transaction_id
    assert_equal ckb_transaction.id, UdtAddressTransaction.last.ckb_transaction_id
    assert_equal ckb_transaction.udt_address_ids, UdtAddressTransaction.all.map{|e| e.udt_address_id}
  end

end
