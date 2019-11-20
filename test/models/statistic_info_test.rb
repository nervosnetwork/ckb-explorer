require "test_helper"

class StatisticInfoTest < ActiveSupport::TestCase
  test "should has default statistical interval" do
    statistic_info = StatisticInfo.new

    assert_not_nil statistic_info.instance_variable_get(:@hash_rate_statistical_interval)
  end

  test "the default statistical interval should equal to env config" do
    statistic_info = StatisticInfo.new

    assert_equal 100, statistic_info.instance_variable_get(:@hash_rate_statistical_interval)
  end

  test "id should present" do
    statistic_info = StatisticInfo.new

    assert_not_nil statistic_info.id
  end

  test ".tip_block_number should return tip block number of the connected node" do
    statistic_info = StatisticInfo.new
    create(:block, :with_block_hash, number: 100)
    assert_equal 100, statistic_info.tip_block_number
  end

  test ".current_epoch_difficulty should return current epoch difficulty" do
    CkbSync::Api.any_instance.stubs(:get_current_epoch).returns(
      CKB::Types::Epoch.new(
        compact_target: "0x1000",
        length: "0x07d0",
        number: "0x0",
        start_number: "0x0"
      )
    )
    statistic_info = StatisticInfo.new

    current_epoch_difficulty = CkbUtils.compact_to_difficulty(CkbSync::Api.instance.get_current_epoch.compact_target)
    assert_equal current_epoch_difficulty, statistic_info.current_epoch_difficulty
  end

  test ".average_block_time should return latest 100 average block time" do
    statistic_info = StatisticInfo.new
    ended_at = DateTime.now
    create(:block, :with_block_hash, number: 0)
    101.times do |num|
      create(:block, :with_block_hash, number: num, timestamp: (ended_at - 23.hours).strftime("%Q").to_i + num)
    end

    blocks = Block.order(timestamp: :desc).limit(ENV["AVERAGE_BLOCK_TIME_INTERVAL"].to_i)
    total_block_time = (blocks.first.timestamp - blocks.last.timestamp).to_d

    average_block_time = total_block_time.to_d / blocks.size
    assert_equal average_block_time, statistic_info.average_block_time
  end

  test ".hash_rate should return average hash rate of the last 500 blocks" do
    statistic_info = StatisticInfo.new
    create_list(:block, 500, :with_block_hash)
    block_count = ENV["HASH_RATE_STATISTICAL_INTERVAL"]
    last_500_blocks = Block.recent.includes(:uncle_blocks).limit(block_count.to_i)
    total_difficulties = last_500_blocks.flat_map { |block| [block, *block.uncle_blocks] }.reduce(0) { |sum, block| sum + block.difficulty }
    total_time = last_500_blocks.first.timestamp - last_500_blocks.last.timestamp
    hash_rate = total_difficulties.to_d / total_time

    assert_equal hash_rate, statistic_info.hash_rate
  end
end
