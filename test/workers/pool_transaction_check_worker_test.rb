require "test_helper"

class PoolTransactionCheckWorkerTest < ActiveSupport::TestCase
  setup do
    PoolTransactionCheckWorker.any_instance.stubs(:generate_json_rpc_id).returns(1)
  end
  test "should detect and mark failed tx from pending tx, for inputs" do
    Sidekiq::Testing.inline!
    rejected_tx_id = '0xed2049c21ffccfcd26281d60f8f77ff117adb9df9d3f8cbe5fe86e893c66d359'
    create :pool_transaction_entry, tx_status: 'pending',
      inputs: [
        {
          "since": 0,
          "previous_output": {
            "index": 0,
            "tx_hash": rejected_tx_id
          }
        },
      ],
      cell_deps: []

    VCR.use_cassette('get_rejected_transaction') do
      PoolTransactionCheckWorker.perform_async
      pool_transaction_entry = PoolTransactionEntry.last
      assert_equal 'rejected', pool_transaction_entry.tx_status
      assert pool_transaction_entry.detailed_message.include?("Resolve failed Dead")
    end
  end

  test "should detect and mark failed tx from pending tx, for cell_deps" do
    Sidekiq::Testing.inline!
    rejected_tx_id = '0xed2049c21ffccfcd26281d60f8f77ff117adb9df9d3f8cbe5fe86e893c66d359'
    create :pool_transaction_entry, tx_status: 'pending',
      inputs: [],
      cell_deps: [
        {
          "dep_type": "dep_group",
          "out_point": {
            "index": 0,
            "tx_hash": "0xd48ebd7c52ee3793ccaeef9ab40c29281c1fc4e901fb52b286fc1af74532f1cb"
          }
        },
        {
          "dep_type": "dep_group",
          "out_point": {
            "index": 0,
            "tx_hash": rejected_tx_id
          }
        }
      ]

    VCR.use_cassette('get_rejected_transaction') do
      PoolTransactionCheckWorker.perform_async

      pool_transaction_entry = PoolTransactionEntry.last
      assert_equal 'rejected', pool_transaction_entry.tx_status
      assert pool_transaction_entry.detailed_message.include?("Resolve failed Dead")
    end
  end
end