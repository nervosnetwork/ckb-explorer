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
    tip_block.number
  end

  def tip_block_hash
    tip_block.block_hash
  end

  def epoch_info
    { epoch_number: tip_block.epoch.to_s, epoch_length: tip_block.length.to_s, index: (tip_block_number - tip_block.start_number).to_s }
  end

  def estimated_epoch_time
    if hash_rate.present?
      (tip_block.difficulty * tip_block.length / hash_rate).truncate(6)
    end
  end

  def transactions_last_24hrs
    Block.h24.sum(:ckb_transactions_count).to_i
  end

  def transactions_count_per_minute(interval = 100)
    start_block_number = [tip_block_number.to_i - interval + 1, 0].max
    timestamps = Block.where(number: [start_block_number, tip_block_number]).recent.pluck(:timestamp)
    return if timestamps.empty?

    transactions_count = Block.where(number: start_block_number..tip_block_number).sum(:ckb_transactions_count)

    (transactions_count / (total_block_time(timestamps) / 1000 / 60)).truncate(3)
  end

  def current_epoch_difficulty
    tip_block.difficulty
  end

  def average_block_time(interval = average_block_time_interval)
    start_block_number = [tip_block_number.to_i - interval + 1, 0].max
    timestamps = Block.where(number: [start_block_number, tip_block_number]).recent.pluck(:timestamp)
    return if timestamps.empty?

    total_block_time(timestamps) / blocks_count(interval)
  end

  def hash_rate(block_number = tip_block_number)
    blocks = Block.where("number <= ?", block_number).recent.includes(:uncle_blocks).limit(hash_rate_statistical_interval)
    return if blocks.blank?

    total_difficulties = blocks.flat_map { |block| [block, *block.uncle_blocks] }.reduce(0) { |sum, block| sum + block.difficulty }
    total_time = blocks.first.timestamp - blocks.last.timestamp

    (total_difficulties.to_d / total_time).truncate(6)
  end

  def miner_ranking
    MinerRanking.new.ranking
  end

  def address_balance_ranking
    addresses = Address.visible.where("balance > 0").order(balance: :desc).limit(50)
    addresses.each.with_index(1).map do |address, index|
      { ranking: index.to_s, address: address.address_hash, balance: address.balance.to_s }
    end
  end

  def blockchain_info
    CkbSync::Api.instance.get_blockchain_info
  end

  def maintenance_info
    Rails.cache.fetch("maintenance_info")
  end

  def flush_cache_info
    Rails.cache.realize("flush_cache_info") || []
  end

  private

  attr_reader :hash_rate_statistical_interval, :average_block_time_interval

  def total_block_time(timestamps)
    (timestamps.first - timestamps.last).to_d
  end

  def blocks_count(interval = average_block_time_interval)
    tip_block_number > interval ? interval : tip_block_number
  end

  def tip_block
    @tip_block ||= Block.recent.first || OpenStruct.new(number: 0, epoch: 0, length: 0, start_number: 0, difficulty: 0)
  end
end
