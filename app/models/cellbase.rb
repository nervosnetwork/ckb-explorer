class Cellbase
  attr_reader :target_block_number

  def initialize(block)
    @block = block
    @target_block_number = @block.target_block.present? ? @block.target_block_number : 0
  end

  def proposal_reward
    return if block.genesis_block?

    cellbase_output_capacity_details.proposal_reward.to_i
  end

  def commit_reward
    return if block.genesis_block?

    cellbase_output_capacity_details.tx_fee.to_i
  end

  def base_reward
    return if block.genesis_block?

    cellbase_output_capacity_details.primary.to_i
  end

  def secondary_reward
    return if block.genesis_block?

    cellbase_output_capacity_details.secondary.to_i
  end

  private

  attr_reader :block

  def cellbase_output_capacity_details
    @cellbase_output_capacity_details ||=
      begin
        if block.target_block_reward_status == "issued"
          target_block = block.target_block
          OpenStruct.new(primary: target_block.primary_reward, secondary: target_block.secondary_reward, proposal_reward: target_block.proposal_reward, tx_fee: target_block.commit_reward)
        else
          CkbSync::Api.instance.get_cellbase_output_capacity_details(block.block_hash) || OpenStruct.new(primary: 0, secondary: 0, proposal_reward: 0, tx_fee: 0)
        end
      end
  end
end
