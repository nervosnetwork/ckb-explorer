require "test_helper"

class MinerRankingTest < ActiveSupport::TestCase
  test ".miner_ranking should return miner raking based on rewards desc" do
    miner_ranking = MinerRanking.new
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).with(0).returns(
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
    address1, address2, address3 = generate_miner_ranking_related_data
    assert_equal expected_ranking(address1, address2, address3), miner_ranking.ranking
  end

  def block_reward(block, epoch_info)
    block_number = block.number
    start_number = epoch_info.start_number.to_i
    remainder_reward = epoch_info.remainder_reward.to_i
    block_reward = epoch_info.block_reward.to_i
    if block_number >= start_number && block_number < start_number + remainder_reward
      block_reward + 1
    else
      block_reward
    end
  end
end


