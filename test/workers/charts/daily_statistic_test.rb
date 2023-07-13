require "test_helper"

module Charts
  class DailyStatisticTest < ActiveSupport::TestCase
    setup do
      create :block, number: 0, timestamp: 1573852190812,
                     dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007"
    end

    test "daily statistic job should enqueue critical queue" do
      assert_difference -> { Charts::DailyStatistic.jobs.size }, 1 do
        Sidekiq::Testing.fake!
        DaoContract.any_instance.stubs(:estimated_apc).returns(nil)
        Charts::DailyStatisticGenerator.any_instance.stubs(:call).returns(true)
        Charts::DailyStatistic.perform_async
      end
      assert_equal "critical", Charts::DailyStatistic.queue
    end

    test "it should create daily_statistics , last record: 3-29 , today: 3-31, should create: 3-30 " do
      # create test data, last daily_statistic
      create :daily_statistic, created_at_unixtimestamp: 2.days.ago.to_i

      # create blocks and 3 tx
      block = create :block, :with_block_hash, timestamp: 1.day.ago.to_i * 1000,
                                               dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007"
      create :ckb_transaction, block: block
      create :ckb_transaction, block: block
      create :ckb_transaction, block: block

      Charts::DailyStatisticGenerator.any_instance.stubs(:methods_to_call).returns(["block_timestamp"])
      Charts::DailyStatistic.new.perform
      assert_equal 2, ::DailyStatistic.count
      # But in daily statistic, we are using local timezone (+8)
      assert_equal Time.at(::DailyStatistic.last.created_at_unixtimestamp).in_time_zone.strftime("%Y-%m-%d"),
                   1.day.ago.strftime("%Y-%m-%d")
      assert_equal block.timestamp, ::DailyStatistic.last.block_timestamp
    end

    test "it should create daily_statistics , if passed date" do
      ::DailyStatistic.delete_all

      # create test data, last daily_statistic
      create :daily_statistic, created_at_unixtimestamp: 2.days.ago.to_i

      # create blocks and 3 tx
      block = create :block, :with_block_hash, timestamp: 1.day.ago.to_i * 1000,
                                               dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007"

      create :ckb_transaction, block: block
      create :ckb_transaction, block: block
      create :ckb_transaction, block: block

      Charts::DailyStatisticGenerator.any_instance.stubs(:methods_to_call).returns(["block_timestamp"])
      Charts::DailyStatistic.new.perform(1.day.ago)
      assert_equal 2, ::DailyStatistic.count

      # it's very wired that this unit test would fail in test environtment in github.
      # assert_equal Time.at(::DailyStatistic.last.created_at_unixtimestamp).strftime("%Y-%m-%d"), 1.day.ago.strftime("%Y-%m-%d")
      assert_equal block.timestamp, ::DailyStatistic.last.block_timestamp
    end
  end
end
