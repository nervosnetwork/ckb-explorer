require "test_helper"

class GlobalStatisticTest < ActiveSupport::TestCase
  test "should save new record" do
    GlobalStatistic.create name: 'my_table_count', value: 88
    assert_equal GlobalStatistic.last.value, 88
  end

  test "should reset_ckb_transactions_count" do
    GlobalStatistic.reset_ckb_transactions_count
    block1 = create :block, :with_block_hash, :with_block_number
    create(:ckb_transaction, block: block1)
    block2 = create :block, :with_block_hash, :with_block_number
    create(:ckb_transaction, block: block2)
    assert_equal GlobalStatistic.find_by_name('ckb_transactions').value, 2
  end
end
