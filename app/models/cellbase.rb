class Cellbase
  attr_reader :target_block_number

  def initialize(block)
    @block = block
    @target_block_number = @block.target_block.present? ? @block.target_block_number : 0
  end

  def proposal_reward
    return if block.genesis_block?

    block_economic_state.miner_reward.proposal
  end

  def commit_reward
    return if block.genesis_block?

    block_economic_state.miner_reward.committed
  end

  def base_reward
    return if block.genesis_block?

    block_economic_state.miner_reward.primary
  end

  def secondary_reward
    return if block.genesis_block?

    block_economic_state.miner_reward.secondary
  end

  private

  attr_reader :block

  def block_economic_state
    @block_economic_state ||=
      if block.target_block_reward_status == "issued"
        target_block = block.target_block
        miner_reward = OpenStruct.new(
          primary: target_block.primary_reward,
          secondary: target_block.secondary_reward,
          proposal: target_block.proposal_reward,
          committed: target_block.commit_reward
        )
        OpenStruct.new(miner_reward: miner_reward)
      else
        CkbSync::Api.instance.get_block_economic_state(block.target_block.block_hash) ||
          OpenStruct.new(miner_reward: OpenStruct.new(
            primary: 0, secondary: 0, proposal: 0, committed: 0
          ))
      end
  end
end
