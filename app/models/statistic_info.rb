class StatisticInfo
  def initialize(hash_rate_statistical_interval: nil)
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
    CkbSync::Api.instance.get_current_epoch.difficulty.hex
  end

  def current_epoch_average_block_time
    current_epoch_number = Block.recent.first&.epoch
    blocks = Block.where(epoch: current_epoch_number).order(:timestamp)
    return if blocks.empty?

    total_block_time(blocks, current_epoch_number) / blocks.size
  end

  def hash_rate(block_number = tip_block_number)
    blocks = Block.where("number <= ?", block_number).recent.includes(:uncle_blocks).limit(hash_rate_statistical_interval.to_i)
    return if blocks.blank?

    total_difficulties = blocks.flat_map { |block| [block, *block.uncle_blocks] }.reduce(0) { |sum, block| sum + block.difficulty.hex }
    total_time = blocks.first.timestamp - blocks.last.timestamp

    total_difficulties.to_d / total_time / cycle_rate
  end

  def miner_ranking
    MinerRanking.new.ranking
  end

  def blockchain_info
    CkbSync::Api.instance.get_blockchain_info
  end

  private

  attr_reader :hash_rate_statistical_interval

  def total_block_time(blocks, current_epoch_number)
    prev_epoch_nubmer = [current_epoch_number.to_i - 1, 0].max
    if prev_epoch_nubmer.zero?
      prev_epoch_last_block = Block.find_by(number: 0)
    else
      prev_epoch_last_block = Block.where(epoch: prev_epoch_nubmer).recent.first
    end
    (blocks.last.timestamp - prev_epoch_last_block.timestamp).to_d
  end

  def n_l(n, l)
    ((n - l + 1)..n).reduce(1, :*)
  end

  # this formula comes from https://www.youtube.com/watch?v=CLiKX0nOsHE&feature=youtu.be&list=PLvgCPbagiHgqYdVUj-ylqhsXOifWrExiq&t=1242
  # n and l is Cuckoo's params
  # on ckb testnet the value of 'n' is 2**15 and the value of 'l' is 12
  # the value of n and l and this formula are unstable, will change as the POW changes.
  def cycle_rate
    n = 2**15
    l = 12
    n_l(n, l).to_f / (n**l) * (n_l(n, l / 2)**2) / (n**l) / l
  end
end
