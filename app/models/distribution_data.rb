class DistributionData
  VALID_INDICATORS = %w(
    address_balance_distribution block_time_distribution epoch_time_distribution epoch_length_distribution
    average_block_time nodes_distribution miner_address_distribution updated_at
  ).freeze

  def id
    Time.current.to_i
  end

  def address_balance_distribution
    DailyStatistic.recent.first&.address_balance_distribution || []
  end

  def block_time_distribution
    DailyStatistic.recent.first&.block_time_distribution || []
  end

  def epoch_time_distribution
    DailyStatistic.recent.first&.epoch_time_distribution || []
  end

  def epoch_length_distribution
    DailyStatistic.recent.first&.epoch_length_distribution || []
  end

  def average_block_time
    DailyStatistic.recent.first&.average_block_time || []
  end

  def nodes_distribution
    DailyStatistic.recent.first&.nodes_distribution || DailyStatistic.where.not(nodes_distribution: nil).recent.first&.nodes_distribution || []
  end

  def created_at_unixtimestamp
    DailyStatistic.recent.first&.created_at_unixtimestamp
  end

  def miner_address_distribution(checkpoint = 7)
    supported_checkpoints = [7, 90]
    return unless checkpoint.in?(supported_checkpoints)

    Rails.cache.realize("miner_address_distribution_#{checkpoint}", expires_in: 1.day) do
      result = Block.where("timestamp >= ?", CkbUtils.time_in_milliseconds(checkpoint.days.ago.to_i)).group(:miner_hash).order("count(miner_hash) desc").count.to_a
      cut_off_point = (result.count * 0.7).floor
      if result.present?
        (result[0..cut_off_point].map { |item| [item[0], item[1].to_s] } + [["other", result[(cut_off_point + 1)..-1].pluck(1).reduce(:+).to_s]]).to_h
      else
        result
      end
    end
  end
end
