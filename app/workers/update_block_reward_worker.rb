class UpdateBlockRewardWorker
  include Sidekiq::Worker
  sidekiq_options queue: "block_reward_updater", lock: :until_executed

  def perform(block_id)
    block = Block.find(block_id)

    CkbSync::Persist.update_block_reward_info(block)
  end
end
