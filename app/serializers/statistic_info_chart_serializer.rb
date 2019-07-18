class StatisticInfoChartSerializer
  include FastJsonapi::ObjectSerializer

  attributes :hash_rate, :difficulty
end
