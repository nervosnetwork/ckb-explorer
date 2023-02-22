require "test_helper"

class DaoAddressTransactionTest < ActiveSupport::TestCase
  setup do
    @block = create(:block, :with_block_hash)
    @address = create :address
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block, dao_address_ids: [@address.id, @address.id + 1])
    @dao_address_transaction = create :dao_address_transaction, ckb_transaction_id: @ckb_transaction.id, dao_address_id: @ckb_transaction.dao_address_ids.first
  end

  context "associations" do
    should belong_to(:ckb_transaction)
    should belong_to(:address)
  end

  test "it should create dao_address_transaction" do
    assert_equal @ckb_transaction.id, @dao_address_transaction.ckb_transaction_id
    assert_equal @ckb_transaction.dao_address_ids.first, @dao_address_transaction.dao_address_id
    assert_equal @address.id, @dao_address_transaction.dao_address_id
  end

  test "it should create_initial_data" do
    CkbTransaction.delete_all
    DaoAddressTransaction.delete_all
    block = create(:block, :with_block_hash)
    address = create :address
    ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block, dao_address_ids: [address.id, address.id + 1])

    # for the 1st time, it will create
    DaoAddressTransaction.create_initial_data CkbTransaction.all
    assert_equal ckb_transaction.dao_address_ids.size, DaoAddressTransaction.count
    assert_equal ckb_transaction.id, DaoAddressTransaction.first.ckb_transaction_id
    assert_equal ckb_transaction.id, DaoAddressTransaction.last.ckb_transaction_id
    assert_equal ckb_transaction.dao_address_ids, DaoAddressTransaction.all.map{|e| e.dao_address_id}

    # for the 2nd time, it should NOT create new record
    DaoAddressTransaction.create_initial_data CkbTransaction.all
    assert_equal ckb_transaction.dao_address_ids.size, DaoAddressTransaction.count
    assert_equal ckb_transaction.id, DaoAddressTransaction.first.ckb_transaction_id
    assert_equal ckb_transaction.id, DaoAddressTransaction.last.ckb_transaction_id
    assert_equal ckb_transaction.dao_address_ids, DaoAddressTransaction.all.map{|e| e.dao_address_id}

  end
end
