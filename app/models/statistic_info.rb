class StatisticInfo
  def initialize(hash_rate_statistical_interval: 100)
    @hash_rate_statistical_interval = hash_rate_statistical_interval.presence || ENV["HASH_RATE_STATISTICAL_INTERVAL"]
  end

  def cache_key
    tip_block_number
  end

  def id
    Time.current.to_i
  end

  def tip_block_number
    @tip_block_number ||= CkbSync::Api.instance.get_tip_block_number
  end

  def current_epoch_difficulty
    compact_target = CkbSync::Api.instance.get_current_epoch.compact_target
    CkbUtils.compact_to_difficulty(compact_target)
  end

  def current_epoch_average_block_time
    blocks = Block.order(timestamp: :desc).limit(hash_rate_statistical_interval.to_i)
    return if blocks.empty?

    total_block_time(blocks) / blocks.size
  end

  def hash_rate(block_number = tip_block_number)
    blocks = Block.where("number <= ?", block_number).recent.includes(:uncle_blocks).limit(hash_rate_statistical_interval.to_i)
    return if blocks.blank?

    total_difficulties = blocks.flat_map { |block| [block, *block.uncle_blocks] }.reduce(0) { |sum, block| sum + block.difficulty }
    total_time = blocks.first.timestamp - blocks.last.timestamp

    total_difficulties.to_d / total_time
  end

  def miner_ranking
    MinerRanking.new.ranking
  end

  def blockchain_info
    CkbSync::Api.instance.get_blockchain_info
  end

  private

  attr_reader :hash_rate_statistical_interval

  def total_block_time(blocks)
    (blocks.first.timestamp - blocks.last.timestamp).to_d
  end
end
