class DistributionData
  VALID_INDICATORS = %w(address_balance_distribution block_time_distribution epoch_time_distribution epoch_length_distribution average_block_time_distribution).freeze

  def id
    Time.current.to_i
  end

  def address_balance_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.address_balance_distribution || []
  end

  def block_time_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.block_time_distribution || []
  end

  def epoch_time_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.epoch_time_distribution || []
  end

  def epoch_length_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.epoch_length_distribution || []
  end

  def average_block_time_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.average_block_time_distribution || []
  end
end
