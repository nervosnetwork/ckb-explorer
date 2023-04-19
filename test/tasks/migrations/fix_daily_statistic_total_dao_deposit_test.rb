require 'test_helper'
require 'rake'

class FixDailyStatisticTotalDaoDepositTaskTest < ActiveSupport::TestCase
  setup do
    @normal_statistic = create(:daily_statistic, created_at_unixtimestamp: "1669564800", total_dao_deposit: 1_000_000_000) # 2022-11-27 16:00 UTC
    @wrong_time_statistic = create(:daily_statistic, created_at_unixtimestamp: "1669507500") # 2022-11-27 00:05 UTC

    Charts::DailyStatisticGenerator.any_instance.stubs(:call).returns(true)
    Server::Application.load_tasks if Rake::Task.tasks.empty?
  end

  test "delete wrong time statistic" do
    Rake::Task['migration:fix_daily_statistic_total_dao_deposit'].execute
    assert_nil DailyStatistic.find_by(created_at_unixtimestamp: "1669507500")
  end

  test "create lost record" do
    lost_number = (Date.yesterday - Date.new(2019,11,15)).to_i
    Charts::DailyStatisticGenerator.any_instance.expects(:call).times(lost_number)
    Rake::Task['migration:fix_daily_statistic_total_dao_deposit'].execute
  end

  test "update total_dao_deposit" do
    create(:dao_event, status: :processed, event_type: :deposit_to_dao, value: 333_333_333, block_timestamp: 1669564700)
    old_created_at = @normal_statistic.created_at
    old_updated_at = @normal_statistic.updated_at
    
    Rake::Task['migration:fix_daily_statistic_total_dao_deposit'].execute
    @normal_statistic.created_at
    assert_equal @normal_statistic.reload.total_dao_deposit, "333333333"
    assert_equal old_created_at, @normal_statistic.reload.created_at
    refute_equal old_updated_at, @normal_statistic.reload.updated_at
  end
end