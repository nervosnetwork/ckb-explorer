require "test_helper"

module Charts
  class DailyStatisticTest < ActiveSupport::TestCase
    test "daily statistic job should enqueue critical queue" do
      assert_difference -> { Charts::DailyStatistic.jobs.size }, 1 do
        Sidekiq::Testing.fake!
        DaoContract.any_instance.stubs(:estimated_apc).returns(nil)
        Charts::DailyStatisticGenerator.any_instance.stubs(:call).returns(true)
        Charts::DailyStatistic.perform_async
      end
      assert_equal "critical", Charts::DailyStatistic.queue
    end

    test "it should create daily statistic before today" do
      ::DailyStatistic.where('created_at_unixtimestamp > ?', 3.days.ago.to_i).delete_all
      puts "DailyStatistic.last.created_at_unixtimestamp"
      puts Time.at(::DailyStatistic.last.created_at_unixtimestamp)
      count = ::DailyStatistic.count
      Charts::DailyStatistic.new(datetime).perform
      assert_equal count + 2, ::DailyStatistic.count
    end

  end
end
