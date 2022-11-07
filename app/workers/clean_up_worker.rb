# refresh materialized views periodically
class AverageBlockTimeGenerator
  include Sidekiq::Worker

  def perform
    TokenCollection.remove_corrupted
  end
end
