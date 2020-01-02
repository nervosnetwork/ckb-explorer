require "test_helper"

module Charts
  class BlockStatisticTest < ActiveSupport::TestCase
    test "block statistic job should enqueue critical queue" do
      Sidekiq::Testing.fake!
      assert_difference -> { Charts::BlockStatistic.jobs.size }, 1 do
        Charts::BlockStatistic.perform_async
      end
      assert_equal "critical", Charts::BlockStatistic.queue
    end
  end
end
