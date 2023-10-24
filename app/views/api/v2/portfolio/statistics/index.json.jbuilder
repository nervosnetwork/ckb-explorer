json.data do
  json.portfolio_statistic do
    json.call(@portfolio_statistic, :id, :capacity, :occupied_capacity, :dao_deposit, :interest,
              :unclaimed_compensation)
  end
end
