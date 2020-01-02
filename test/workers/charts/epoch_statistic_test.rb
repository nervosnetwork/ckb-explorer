require "test_helper"

module Charts
  class EpochStatisticTest < ActiveSupport::TestCase
    test "block statistic job should enqueue critical queue" do
      Sidekiq::Testing.fake!
      assert_difference -> { Charts::EpochStatistic.jobs.size }, 1 do
        Charts::EpochStatistic.perform_async
      end
      assert_equal "critical", Charts::EpochStatistic.queue
    end
  end
end
