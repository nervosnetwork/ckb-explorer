class Cellbase
  attr_reader :target_block_number

  def initialize(block)
    @block = block
    @target_block = block.target_block
    @target_block_number = @target_block.present? ? block.target_block_number : 0
  end

  def proposal_reward
    return if target_block_number < 1 || target_block.blank? || target_block.exist_uncalculated_tx?

    block.cellbase.cell_outputs.first.capacity - target_block.reward - target_block.total_transaction_fee * 0.6
  end

  def commit_reward
    return if target_block_number < 1 || target_block.blank? || target_block.exist_uncalculated_tx?

    target_block.total_transaction_fee * 0.6
  end

  def block_reward
    return if target_block_number < 1 || target_block.blank? || target_block.exist_uncalculated_tx?

    CkbUtils.base_reward(target_block_number, target_block.epoch)
  end

  private

  attr_reader :block, :target_block
end