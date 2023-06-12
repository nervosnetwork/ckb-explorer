require "test_helper"

class StatisticInfoTest < ActiveSupport::TestCase
  setup do
    Settings.stubs(:hash_rate_statistical_interval).returns(900)
    Settings.stubs(:average_block_time_interval).returns(100)
  end

  test "id should present" do
    statistic_info = StatisticInfo.default

    assert_not_nil statistic_info.id
  end

  test ".tip_block_number should return tip block number of the connected node" do
    statistic_info = StatisticInfo.default
    Block.delete_all
    create(:block, :with_block_hash, number: 100)
    assert_equal 100, statistic_info.tip_block_number
  end

  test ".current_epoch_difficulty should return current epoch difficulty" do
    block = create(:block, epoch: 1, length: 1800, start_number: 1000)
    statistic_info = StatisticInfo.default

    assert_equal block.difficulty, statistic_info.current_epoch_difficulty
  end

  test ".average_block_time should return latest 100 average block time" do
    statistic_info = StatisticInfo.default
    ended_at = DateTime.now
    create(:block, :with_block_hash, number: 0)
    101.times do |num|
      create(:block, :with_block_hash, number: num, timestamp: (ended_at - 23.hours).strftime("%Q").to_i + num)
    end

    blocks = Block.order(timestamp: :desc).limit(100)
    total_block_time = (blocks.first.timestamp - blocks.last.timestamp).to_d

    average_block_time = total_block_time.to_d / blocks.size
    statistic_info.reset :average_block_time
    assert_equal average_block_time, statistic_info.average_block_time
  end

  test ".hash_rate should return average hash rate of the last 500 blocks" do
    statistic_info = StatisticInfo.default
    create_list(:block, 500, :with_block_number, :with_block_hash)
    block_count = 900
    last_500_blocks = Block.recent.includes(:uncle_blocks).limit(block_count.to_i)
    total_difficulties = last_500_blocks.flat_map { |block|
                           [block, *block.uncle_blocks]
                         }.reduce(0) { |sum, block| sum + block.difficulty }
    total_time = last_500_blocks.first.timestamp - last_500_blocks.last.timestamp
    hash_rate = total_difficulties.to_d / total_time
    statistic_info.reset :hash_rate
    assert_equal hash_rate, statistic_info.hash_rate
  end

  test ".address_balance_ranking should return top 50 holders list" do
    Address.delete_all
    addresses =
      create_list(:address, 100).each.with_index(1) do |address, index|
        address.update(balance: index * 100)
      end
    expected_address_balance_ranking =
      addresses.sort_by(&:balance).reverse[0..49].each.with_index(1).map do |address, index|
        {
          "ranking" => index.to_s,
          "address" => address.address_hash.to_s,
          "balance" => address.balance.to_s
        }
      end
    statistic_info = StatisticInfo.default
    statistic_info.reset :address_balance_ranking
    # binding.pry
    assert_equal expected_address_balance_ranking, statistic_info.address_balance_ranking
  end
end
