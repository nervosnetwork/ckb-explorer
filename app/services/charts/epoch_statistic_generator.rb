module Charts
  class EpochStatisticGenerator
    def initialize(target_epoch_number)
      @target_epoch_number = target_epoch_number
    end

    def call
      block_in_target_epoch = Block.where(epoch: target_epoch_number).first
      return unless block_in_target_epoch

      blocks_count = Block.where(epoch: target_epoch_number).count
      return unless blocks_count == block_in_target_epoch.length

      epoch_statistic = ::EpochStatistic.find_or_create_by(epoch_number: target_epoch_number)
      epoch_statistic.reset!(
        :difficulty,
        :uncle_rate,
        :hash_rate,
        :epoch_time,
        :epoch_length,
        :largest_tx_hash,
        :largest_tx_bytes,
        :max_tx_cycles,
        :max_block_cycles,
        :largest_block_number,
        :largest_block_size
      )
    end

    private

    attr_reader :target_epoch_number
  end
end
