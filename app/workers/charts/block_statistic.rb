module Charts
  class BlockStatistic
    include Sidekiq::Worker
    sidekiq_options unique: :until_executed
    sidekiq_options retry: false
    sidekiq_options queue: "critical"

    def perform
      latest_block_number = ::BlockStatistic.order(block_number: :desc).pick(:block_number)
      target_block_number = latest_block_number + 100
      target_block = Block.find_by(number: target_block_number)
      return if target_block.blank? || ::BlockStatistic.where(block_number: target_block_number).exists?

      Charts::BlockStatisticGenerator.new(target_block_number).call
    end
  end
end
