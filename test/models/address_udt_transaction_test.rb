require "test_helper"

class AddressUdtTransactionTest < ActiveSupport::TestCase
  setup do
    @block = create(:block, :with_block_hash)
    @address = create :address
    @address2 = create :address
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block, udt_address_ids: [@address.id, @address2.id])
    @address_udt_transactions = AddressUdtTransaction.where(ckb_transaction_id: @ckb_transaction.id).to_a
  end

  test "it should create address_udt_transaction" do
    ids = @address_udt_transactions.map(&:address_id)
    assert_equal @ckb_transaction.contained_udt_address_ids, ids
    assert_equal [@address.id, @address2.id], ids
  end
end
