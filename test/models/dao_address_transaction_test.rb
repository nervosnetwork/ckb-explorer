require "test_helper"

class DaoAddressTransactionTest < ActiveSupport::TestCase
  setup do
    @block = create(:block, :with_block_hash)
    @address = create :address
    @ckb_transaction = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: @block, dao_address_ids: [@address.id, @address.id + 1])
    @dao_address_transaction = create :dao_address_transaction, ckb_transaction_id: @ckb_transaction.id, dao_address_id: @ckb_transaction.dao_address_ids.first
    @dao_address_transactions = @ckb_transaction.dao_address_ids.map { |dao_address_id|
      create :dao_address_transaction, ckb_transaction_id: @ckb_transaction.id, dao_address_id: dao_address_id
    }
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

  test "it should create initial data" do
    assert_equal @ckb_transaction.dao_address_ids, @dao_address_transactions.map {|dao_address_transaction| dao_address_transaction.dao_address_id}
  end

end
