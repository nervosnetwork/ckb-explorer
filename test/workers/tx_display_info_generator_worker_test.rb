require "test_helper"

class TxDisplayInfoGeneratorWorkerTest < ActiveSupport::TestCase
	test "block statistic job should enqueue critical queue" do
		Sidekiq::Testing.fake!
		assert_difference -> { TxDisplayInfoGeneratorWorker.jobs.size }, 1 do
			block = create(:block)
			create_list(:ckb_transaction, 10, block: block)
			TxDisplayInfoGeneratorWorker.perform_async(CkbTransaction.ids)
		end
		assert_equal "default", TxDisplayInfoGeneratorWorker.queue
	end
end
