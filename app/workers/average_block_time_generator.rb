class AverageBlockTimeGenerator
  include Sidekiq::Worker

  def perform
    AverageBlockTimeByHour.refresh
    RollingAvgBlockTime.refresh
  end
end
