class MinerRanking
  STARTED_AT_TIMESTAMP = 1560578400000
  ENDED_AT_TIMESTAMP = 1561788000000
  DEFAULT_LIMIT = 5

  def id
    Time.current.to_i
  end

  def ranking(limit = nil)
    limit = limit.presence || DEFAULT_LIMIT
    Rails.cache.realize("miner_ranking", expires_in: 1.hour, race_condition_ttl: 10.seconds) do
      ranking_infos.take(limit)
    end
  end

  def ranking_infos
    ckb_transactions =
      CkbTransaction.
        where("block_timestamp >= ? and block_timestamp <= ?", STARTED_AT_TIMESTAMP, ENDED_AT_TIMESTAMP).
        where(is_cellbase: true).
        where.not(block_number: 0)
    only_one_cell_output_txs_id =
      CellOutput.
        where(ckb_transaction: ckb_transactions).
        group(:ckb_transaction_id).
        having("count(*) = 1").
        pluck("ckb_transaction_id")
    address_ids = AccountBook.where(ckb_transaction: only_one_cell_output_txs_id).pluck(:address_id).uniq
    more_than_one_cell_output_txs_id =
      CellOutput.
        where(ckb_transaction: ckb_transactions).
        group(:ckb_transaction_id).having("count(*) > 1").
        pluck("ckb_transaction_id")
    if more_than_one_cell_output_txs_id.present?
      address_ids +=
        CkbTransaction.where(id: more_than_one_cell_output_txs_id).map do |ckb_transaction|
          ckb_transaction.cell_outputs.first.address_id
        end
    end
    addresses = Address.where(id: address_ids)
    ranking_infos = []
    addresses.find_each do |address|
      block_ids = address.ckb_transactions.where(is_cellbase: true).pluck("block_id")
      blocks = Block.where(id: block_ids)
      total_base_reward = 0
      blocks.find_each do |block|
        total_base_reward += CkbUtils.base_reward(block.number, block.epoch)
      end
      ranking_infos << {
        lock_hash: address.lock_hash,
        address_hash: address.address_hash,
        total_base_reward: total_base_reward
      }
    end

    ranking_infos.sort_by { |ranking_info| ranking_info[:total_base_reward] }.reverse
  end
end
