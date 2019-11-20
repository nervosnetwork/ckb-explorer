class StatisticInfo
  def initialize(hash_rate_statistical_interval: ENV["HASH_RATE_STATISTICAL_INTERVAL"], average_block_time_interval: ENV["AVERAGE_BLOCK_TIME_INTERVAL"])
    @hash_rate_statistical_interval = hash_rate_statistical_interval.to_i
    @average_block_time_interval = average_block_time_interval.to_i
  end

  def cache_key
    tip_block_number
  end

  def id
    Time.current.to_i
  end

  def tip_block_number
    @tip_block_number ||= Block.order(timestamp: :desc).pick(:number)
  end

  def current_epoch_difficulty
    compact_target = CkbSync::Api.instance.get_current_epoch.compact_target
    CkbUtils.compact_to_difficulty(compact_target)
  end

  def average_block_time
    start_block_number = [tip_block_number.to_i - average_block_time_interval + 1, 0].max
    timestamps = Block.where(number: [start_block_number, tip_block_number]).order(timestamp: :desc).pluck(:timestamp)
    return if timestamps.empty?

    total_block_time(timestamps) / blocks_count
  end

  def hash_rate(block_number = tip_block_number)
    blocks = Block.where("number <= ?", block_number).recent.includes(:uncle_blocks).limit(hash_rate_statistical_interval)
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

  attr_reader :hash_rate_statistical_interval, :average_block_time_interval

  def total_block_time(timestamps)
    (timestamps.first - timestamps.last).to_d
  end

  def blocks_count
    tip_block_number > average_block_time_interval ? average_block_time_interval : tip_block_number
  end
end
