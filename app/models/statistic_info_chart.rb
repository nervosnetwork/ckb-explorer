class StatisticInfoChart
  def initialize
    @statistic_info = StatisticInfo.new(hash_rate_statistical_interval: 100)
  end

  def id
    Time.current.to_i
  end

  def hash_rate
    to = Rails.cache.read("hash_rate_to")
    Rails.cache.realize("hash_rate_chart_data_#{to}", expires_in: 15.hours)&.uniq || []
  end

  def uncle_rate
    blocks_count = Block.group(:epoch).order(:epoch).count
    uncles_count = Block.group(:epoch).order(:epoch).sum(:uncles_count)
    blocks_count.map do |key, value|
      { epoch_number: key, uncle_rate: uncles_count[key] / value.to_f }
    end
  end

  def difficulty
    current_epoch_number = CkbSync::Api.instance.get_current_epoch.number

    Rails.cache.realize("statistic_info_difficulty_#{current_epoch_number}", expires_in: 10.minutes, race_condition_ttl: 10.seconds) do
      from = Block.where(epoch: 0).recent.first&.number.to_i
      to = Block.maximum(:number).to_i
      hash_rate_block_numbers = (from + 1).step(to, 100).to_a
      hash_rate_blocks = Block.where(number: hash_rate_block_numbers).order(:timestamp)
      blocks = Block.order(:epoch, :timestamp).select("distinct on (epoch) *")
      (blocks + hash_rate_blocks).uniq.map do |block|
        { epoch_number: block.epoch.to_i, block_number: block.number.to_i, difficulty: block.difficulty }
      end
    end
  end

  def calculate_hash_rate
    from = last_epoch0_block_number
    to = Block.maximum(:number).to_i

    epoch_first_block_numbers = Block.order(:epoch, :timestamp).select("distinct on (epoch) number").to_a.pluck(:number)
    result =
      (from + 1).step(to, 100).to_a.concat(epoch_first_block_numbers).uniq.sort.map do |number|
        hash_rate = statistic_info.hash_rate(number)
        { block_number: number.to_i, hash_rate: hash_rate }
      end

    Rails.cache.write("hash_rate_to", to)
    Rails.cache.write("hash_rate_chart_data_#{to}", result.compact.uniq, expires_in: 15.hours)
  end

  private

  attr_reader :statistic_info

  def last_epoch0_block_number
    current_epoch_number = CkbSync::Api.instance.get_current_epoch.number.to_i
    if current_epoch_number > 0
      Block.where(epoch: 0).recent.first&.number.to_i
    else
      Block.recent.order("timestamp asc").first&.number.to_i
    end
  end
end
