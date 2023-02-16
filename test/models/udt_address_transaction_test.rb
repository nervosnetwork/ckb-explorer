require "test_helper"

class UdtAddressTransactionTest < ActiveSupport::TestCase
  setup do
    @block = create(:block, :with_block_hash)
    @address = create :address
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block, udt_address_ids: [@address.id, @address.id + 1])
    @udt_address_transaction = create :udt_address_transaction, ckb_transaction_id: @ckb_transaction.id, udt_address_id: @ckb_transaction.udt_address_ids.first
    @udt_address_transactions = @ckb_transaction.udt_address_ids.map { |udt_address_id|
      create :udt_address_transaction, ckb_transaction_id: @ckb_transaction.id, udt_address_id: udt_address_id
    }
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
    assert_equal @ckb_transaction.udt_address_ids, @udt_address_transactions.map {|udt_address_transaction| udt_address_transaction.udt_address_id}
  end

end
