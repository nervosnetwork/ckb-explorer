module Charts
  class EpochStatisticGenerator
    def initialize(target_epoch_number)
      @target_epoch_number = target_epoch_number
    end

    def call
      return if Block.where(epoch: target_epoch_number).blank?

      return unless Block.where(epoch: target_epoch_number).count == Block.where(epoch: target_epoch_number).order(:number)[0].length

      blocks_count = Block.where(epoch: target_epoch_number).count
      uncles_count = Block.where(epoch: target_epoch_number).sum(:uncles_count)
      uncle_rate = uncles_count / blocks_count.to_d
      difficulty = Block.where(epoch: target_epoch_number).order(:number)[0].difficulty
      first_block_in_epoch = Block.where(epoch: target_epoch_number).order(:number).select(:timestamp)[0]
      last_lock_in_epoch = Block.where(epoch: target_epoch_number).order(number: :desc).select(:timestamp)[0]
      epoch_time = last_lock_in_epoch.timestamp - first_block_in_epoch.timestamp
      epoch_length = Block.where(epoch: target_epoch_number).order(:number)[0].length
      hash_rate = difficulty * epoch_length / epoch_time

      epoch_statistic = ::EpochStatistic.find_or_create_by(epoch_number: target_epoch_number)
      unless epoch_statistic.largest_block_number
        largest_block = Block.where(epoch: target_epoch_number).order(block_size: :desc).first
        epoch_statistic.largest_block_number = largest_block.number
        epoch_statistic.largest_block_size = largest_block.block_size
      end
      unless epoch_statistic.largest_tx_hash
        largest_tx = CkbTransaction.where(blocks: { epoch: target_epoch_number }).joins(:block).order(bytes: :desc).first
        epoch_statistic.largest_tx_hash = largest_tx.tx_hash
        epoch_statistic.largest_tx_bytes = largest_tx.bytes
      end
      max_cycles_block = Block.where(epoch: target_epoch_number).order(cycles: :desc).first
      epoch_statistic.max_block_cycles = max_cycles_block.cycles
      max_cycles_tx = CkbTransaction.where(blocks: { epoch: target_epoch_number }).joins(:block).order(cycles: :desc).first
      epoch_statistic.max_tx_cycles = max_cycles_tx.cycles
      epoch_statistic.update(
        difficulty: difficulty,
        uncle_rate: uncle_rate,
        hash_rate: hash_rate,
        epoch_time: epoch_time,
        epoch_length: epoch_length
      )
    end

    private

    attr_reader :target_epoch_number
  end
end
