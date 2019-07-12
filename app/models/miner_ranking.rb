class MinerRanking
  STARTED_AT_TIMESTAMP = 1560578400000
  ENDED_AT_TIMESTAMP = 1561788000000
  DEFAULT_LIMIT = 5

  def id
    Time.current.to_i
  end

  def ranking(limit = nil)
    limit = limit.presence || DEFAULT_LIMIT
    Rails.cache.fetch("miner_ranking", expires_in: 1.hour, race_condition_ttl: 10.seconds) do
      ranking_infos.take(limit)
    end
  end

  def ranking_infos
    ckb_transactions = CkbTransaction.available.where("block_timestamp >= ? and block_timestamp <= ?", STARTED_AT_TIMESTAMP, ENDED_AT_TIMESTAMP).where(is_cellbase: true).where.not(block_number: 0)
    only_one_cell_output_txs = CellOutput.where(ckb_transaction: ckb_transactions).group(:ckb_transaction_id).having("count(*) = 1").select("ckb_transaction_id")
    address_ids = AccountBook.where(ckb_transaction: only_one_cell_output_txs).select(:address_id).distinct
    more_than_one_cell_output_txs = CellOutput.where(ckb_transaction: ckb_transactions).group(:ckb_transaction_id).having("count(*) > 1").select("ckb_transaction_id")
    if more_than_one_cell_output_txs.present?
      address_ids = address_ids.pluck(:address_id)
      address_ids += CkbTransaction.where(id: more_than_one_cell_output_txs).map { |ckb_transaction| ckb_transaction.cell_outputs.first.address_id }
    end
    addresses = Address.where(id: address_ids)
    ranking_infos = []
    addresses.find_each do |address|
      block_ids = address.ckb_transactions.available.where(is_cellbase: true).select("block_id")
      blocks = Block.where(id: block_ids)
      total_block_reward = 0
      blocks.find_each do |block|
        total_block_reward += CkbUtils.base_reward(block.number, block.epoch)
      end
      ranking_infos << { address_hash: address.address_hash, lock_hash: address.lock_hash, total_block_reward: total_block_reward }
    end

    ranking_infos.sort_by { |ranking_info| ranking_info[:total_block_reward] }.reverse
  end
end
