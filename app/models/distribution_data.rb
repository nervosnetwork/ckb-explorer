class DistributionData
  VALID_INDICATORS = %w(address_balance_distribution)

  def id
    Time.current.to_i
  end

  def address_balance_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first.address_balance_distribution
  end
end
