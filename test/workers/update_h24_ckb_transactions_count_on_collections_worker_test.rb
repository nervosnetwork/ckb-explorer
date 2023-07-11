require "test_helper"

class UpdateH24CkbTransactionsCountOnUdtsWorkerTest < ActiveJob::TestCase
  test "update h24 transactions count when collection transfers is present" do
    Sidekiq::Testing.inline!
    collection = create(:token_collection)
    10.times do |i|
      item =  create(:token_item, token_id: i, collection: collection)
      5.times do
        block = create(:block, timestamp: (Time.current - i.hours).to_i * 1000)
        ckb_transaction = create(:ckb_transaction, block: block)
        create(:token_transfer, item: item, transaction_id: ckb_transaction.id)
      end
    end

    assert_changes -> { collection.reload.h24_ckb_transactions_count }, from: 0, to: 50 do
      UpdateH24CkbTransactionsCountOnCollectionsWorker.new.perform
    end
  end
end
