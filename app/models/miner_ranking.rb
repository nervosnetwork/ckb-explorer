class MinerRanking
  STARTED_AT_TIMESTAMP = 1560578400000
  ENDED_AT_TIMESTAMP = 1561788000000
  DEFAULT_LIMIT = 5

  def id
    Time.current.to_i
  end

  def ranking(limit = nil)
    limit = limit.presence || DEFAULT_LIMIT
    result =
      Rails.cache.fetch("miner_ranking", expires_in: 1.hour) do
        ckb_transactions = CkbTransaction.where("block_timestamp >= ? and block_timestamp <= ?", STARTED_AT_TIMESTAMP, ENDED_AT_TIMESTAMP).where(is_cellbase: true)
        address_ids = AccountBook.where(ckb_transaction: ckb_transactions).select("address_id").distinct
        addresses = Address.where(id: address_ids)
        ranking_infos = []
        addresses.find_each do |address|
          block_ids = address.ckb_transactions.where(is_cellbase: true).select("block_id")
          blocks = Block.where(id: block_ids)
          total_block_reward = 0
          blocks.find_each do |block|
            epoch_info = CkbUtils.get_epoch_info(block.epoch)
            total_block_reward += block_reward(block, epoch_info)
          end
          ranking_infos << { address_hash: address.address_hash, lock_hash: address.lock_hash, total_block_reward: total_block_reward }
        end

        ranking_infos.sort_by { |ranking_info| ranking_info[:total_block_reward] }.reverse
      end

    if limit.negative?
      result
    else
      result.take(limit)
    end
  end

  private

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