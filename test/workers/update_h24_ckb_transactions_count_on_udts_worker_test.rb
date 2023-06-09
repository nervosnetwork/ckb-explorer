require 'test_helper'

class UpdateH24CkbTransactionsCountOnUdtsWorkerTest < ActiveJob::TestCase

  test "update udt.h24_ckb_transactions_count when udt.ckb_transactions is blank" do
    udt = create(:udt)
    udt.update_h24_ckb_transactions_count
    assert_equal 0, udt.h24_ckb_transactions_count
  end

  test "update udt.h24_ckb_transactions_count when udt.ckb_transactions is present" do
    udt_one = create(:udt)
    udt_two = create(:udt)
    udt_three = create(:udt)
    block = create(:block, :with_block_hash)
    ckb_transaction_one = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: block, block_timestamp: CkbUtils.time_in_milliseconds(4.hours.ago))
    ckb_transaction_two = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: block, block_timestamp: CkbUtils.time_in_milliseconds(3.hours.ago))
    ckb_transaction_three = create(:ckb_transaction, :with_multiple_inputs_and_outputs, block: block, block_timestamp: CkbUtils.time_in_milliseconds(2.hours.ago))
    create(:udt_transaction, udt_id: udt_one.id, ckb_transaction_id: ckb_transaction_one.id)
    create(:udt_transaction, udt_id: udt_one.id, ckb_transaction_id: ckb_transaction_two.id)
    create(:udt_transaction, udt_id: udt_one.id, ckb_transaction_id: ckb_transaction_three.id)
    create(:udt_transaction, udt_id: udt_two.id, ckb_transaction_id: ckb_transaction_two.id)
    create(:udt_transaction, udt_id: udt_two.id, ckb_transaction_id: ckb_transaction_one.id)
    create(:udt_transaction, udt_id: udt_three.id, ckb_transaction_id: ckb_transaction_three.id)
    udt_one.update_h24_ckb_transactions_count
    udt_two.update_h24_ckb_transactions_count
    udt_three.update_h24_ckb_transactions_count
    assert_equal 3, udt_one.h24_ckb_transactions_count
    assert_equal 2, udt_two.h24_ckb_transactions_count
    assert_equal 1, udt_three.h24_ckb_transactions_count
  end

end
