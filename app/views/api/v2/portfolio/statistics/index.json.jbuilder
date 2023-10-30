json.data do
  json.portfolio_statistic do
    json.capacity @portfolio_statistic.capacity.to_s
    json.occupied_capacity @portfolio_statistic.occupied_capacity.to_s
    json.dao_deposit @portfolio_statistic.dao_deposit.to_s
    json.dao_compensation (@portfolio_statistic.interest.to_i + @portfolio_statistic.unclaimed_compensation.to_i).to_s
  end
end
