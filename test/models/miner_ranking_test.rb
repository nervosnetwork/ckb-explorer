require "test_helper"

class MinerRankingTest < ActiveSupport::TestCase
  test ".miner_ranking should return miner raking based on rewards desc" do
    miner_ranking = MinerRanking.new
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).with(0).returns(
      CKB::Types::Epoch.new(
        compact_target: "0x1000",
        length: "0x07d0",
        number: "0x0",
        start_number: "0x0"
      )
    )
    address1, address2, address3 = generate_miner_ranking_related_data
    assert_equal expected_ranking(address1, address2, address3), miner_ranking.ranking
  end

  def base_reward(block_number, epoch_number, cellbase = nil)
    return cellbase.outputs.first.capacity.to_i if block_number.to_i == 0 && cellbase.present?

    epoch_info = CkbSync::Api.instance.get_epoch_by_number(epoch_number)
    start_number = epoch_info.start_number.to_i
    epoch_reward = Settings.default_epoch_reward.to_i
    base_reward = epoch_reward / epoch_info.length.to_i
    remainder_reward = epoch_reward % epoch_info.length.to_i
    if block_number.to_i >= start_number && block_number.to_i < start_number + remainder_reward
      base_reward + 1
    else
      base_reward
    end
  end
end
