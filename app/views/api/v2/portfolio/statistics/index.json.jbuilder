json.data do
  json.portfolio_statistic do
    json.call(@portfolio_statistic, :capacity, :occupied_capacity, :dao_deposit)
    json.dao_compensation @portfolio_statistic.interest.to_i + @portfolio_statistic.unclaimed_compensation.to_i
  end
end
