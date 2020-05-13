class AverageBlockTimeGenerator
  include Sidekiq::Worker

  def perform
    BlockTimeStatistic.new.generate_daily
  end
end
