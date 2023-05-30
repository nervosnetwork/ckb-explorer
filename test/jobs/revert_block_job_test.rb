require "test_helper"

class RevertBlockJobTest < ActiveJob::TestCase
  setup do
    @address = create(:address)
    first_block = create(:block)
    parent_block = create(:block, parent_hash: first_block.hash, address_ids: [@address.id], number: 11)
    @local_block = create(:block, parent_hash: parent_block.hash, address_ids: [@address.id], number: 12)
    _first_block_snapshot = create(:address_block_snapshot, block: first_block, block_number: first_block.number,
                                                            address: @address)
    @local_block_snapshot = create(:address_block_snapshot, block: @local_block, block_number: @local_block.number,
                                                            address: @address)
    @address.update(@local_block_snapshot.attributes.slice("live_cells_count", "ckb_transactions_count", "dao_transactions_count",
                                                           "balance", "balance_occupied"))
    @parent_block_snapshot = create(:address_block_snapshot, block: parent_block, block_number: parent_block.number,
                                                             address: @address)
  end
  test "rollback address info with parent block" do
    assert_equal @address.reload.live_cells_count, @local_block_snapshot.live_cells_count
    assert_equal @address.reload.ckb_transactions_count, @local_block_snapshot.ckb_transactions_count
    assert_equal @address.reload.dao_transactions_count, @local_block_snapshot.dao_transactions_count
    assert_equal @address.reload.balance, @local_block_snapshot.balance
    assert_equal @address.reload.balance_occupied, @local_block_snapshot.balance_occupied

    RevertBlockJob.new(@local_block).update_address_balance_and_ckb_transactions_count(@local_block)

    assert_equal @address.reload.live_cells_count, @parent_block_snapshot.live_cells_count
    assert_equal @address.reload.ckb_transactions_count, @parent_block_snapshot.ckb_transactions_count
    assert_equal @address.reload.dao_transactions_count, @parent_block_snapshot.dao_transactions_count
    assert_equal @address.reload.balance, @parent_block_snapshot.balance
    assert_equal @address.reload.balance_occupied, @parent_block_snapshot.balance_occupied

    assert_nil AddressBlockSnapshot.find_by(id: @local_block_snapshot.id)
  end
end
