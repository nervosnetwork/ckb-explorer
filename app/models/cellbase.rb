class Cellbase
  attr_reader :target_block_number

  def initialize(block)
    @block = block
    @target_block_number = @block.target_block.present? ? @block.target_block_number : 0
    @cellbase_output_capacity_details = CkbSync::Api.instance.get_cellbase_output_capacity_details(block.block_hash)
  end

  def proposal_reward
    return if block.genesis_block?

    cellbase_output_capacity_details.proposal_reward.to_i
  end

  def commit_reward
    return if block.genesis_block?

    cellbase_output_capacity_details.tx_fee.to_i
  end

  def block_reward
    return if block.genesis_block?

    cellbase_output_capacity_details.primary.to_i
  end

  def secondary_reward
    return if block.genesis_block?

    cellbase_output_capacity_details.secondary.to_i
  end

  private

  attr_reader :cellbase_output_capacity_details, :block
end
