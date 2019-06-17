require "test_helper"

class StatisticInfoTest < ActiveSupport::TestCase
  test "should has default difficulty interval" do
    statistic_info = StatisticInfo.new

    assert_not_nil statistic_info.instance_variable_get(:@difficulty_interval)
  end

  test "should has default block time interval" do
    statistic_info = StatisticInfo.new

    assert_not_nil statistic_info.instance_variable_get(:@block_time_interval)
  end

  test "should has default statistical interval" do
    statistic_info = StatisticInfo.new

    assert_not_nil statistic_info.instance_variable_get(:@hash_rate_statistical_interval)
  end

  test "the default difficulty interval should equal to env config" do
    statistic_info = StatisticInfo.new

    assert_equal ENV["DIFFICULTY_INTERVAL"], statistic_info.instance_variable_get(:@difficulty_interval)
  end

  test "the default block time interval should equal to env config" do
    statistic_info = StatisticInfo.new

    assert_equal ENV["BLOCK_TIME_INTERVAL"], statistic_info.instance_variable_get(:@block_time_interval)
  end

  test "the default statistical interval should equal to env config" do
    statistic_info = StatisticInfo.new

    assert_equal ENV["HASH_RATE_STATISTICAL_INTERVAL"], statistic_info.instance_variable_get(:@hash_rate_statistical_interval)
  end

  test "id should present" do
    statistic_info = StatisticInfo.new

    assert_not_nil statistic_info.id
  end

  test ".tip_block_number should return tip block number of the connected node" do
    statistic_info = StatisticInfo.new
    CkbSync::Api.any_instance.expects(:get_tip_block_number).returns(100)

    assert_equal 100, statistic_info.tip_block_number
  end

  test ".current_epoch_difficulty should return current epoch difficulty" do
    CkbSync::Api.any_instance.stubs(:get_current_epoch).returns(
      CKB::Types::Epoch.new(
        block_reward: "250000000000",
        difficulty: "0x1000",
        last_block_hash_in_previous_epoch: "0x0000000000000000000000000000000000000000000000000000000000000000",
        length: "2000",
        number: "0",
        remainder_reward: "0",
        start_number: "0"
      )
    )
    statistic_info = StatisticInfo.new

    current_epoch_difficulty = CkbSync::Api.instance.get_current_epoch.difficulty.hex
    assert_equal current_epoch_difficulty, statistic_info.current_epoch_difficulty
  end

  test ".average_block_time should return average block time within 24 hours" do
    statistic_info = StatisticInfo.new
    ended_at = DateTime.now
    10.times do |num|
      create(:block, :with_block_hash, timestamp: (ended_at - 23.hours).strftime("%Q").to_i + num)
    end

    started_at = ended_at - 24.hours
    started_at_timestamp = started_at.strftime("%Q").to_i
    ended_at_timestamp = ended_at.strftime("%Q").to_i
    blocks = Block.created_after(started_at_timestamp).created_before(ended_at_timestamp).order(:timestamp)
    index = 0
    total_block_time = 0
    blocks.each do
      next if index == 0

      total_block_time += blocks[index].timestamp - blocks[index - 1].timestamp
      index += 1
    end

    average_block_time = total_block_time.to_d / blocks.size
    assert average_block_time - statistic_info.average_block_time < 3000
  end

  test ".hash_rate should return average hash rate of the last 500 blocks" do
    statistic_info = StatisticInfo.new
    create_list(:block, 500, :with_block_hash)
    block_count = ENV["HASH_RATE_STATISTICAL_INTERVAL"]
    last_500_blocks = Block.recent.includes(:uncle_blocks).limit(block_count.to_i)
    total_difficulties = last_500_blocks.flat_map { |block| [block, *block.uncle_blocks] }.reduce(0) { |sum, block| sum + block.difficulty.hex }
    total_time = last_500_blocks.first.timestamp - last_500_blocks.last.timestamp
    cycle_rate = 0.08308952614941366
    hash_rate = total_difficulties.to_d / total_time / cycle_rate

    assert_equal hash_rate, statistic_info.hash_rate
  end
end
