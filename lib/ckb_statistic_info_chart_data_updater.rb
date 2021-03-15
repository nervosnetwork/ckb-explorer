require_relative "../config/environment"

loop do
  statistic_info_chart = StatisticInfoChart.new
  statistic_info_chart.calculate_hash_rate

  sleep(ENV["STATISTIC_INFO_CHART_UPDATER_LOOP_INTERVAL"].to_i)
end
