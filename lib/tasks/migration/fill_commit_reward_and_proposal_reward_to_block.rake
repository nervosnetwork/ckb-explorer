namespace :migration do
  task fill_commit_reward_and_proposal_reward_to_block: :environment do
    progress_bar = ProgressBar.create({
      total: Block.where(reward_status: "issued", proposal_reward: nil).count,
      format: "%e %B %p%% %c/%C"
    })


    Block.where(reward_status: "issued", proposal_reward: nil).order(:number).find_in_batches(batch_size: 3000) do |blocks|
      values =
        blocks.map do |block|
          next if block.genesis_block?

          progress_bar.increment
          economic = CkbSync::Api.instance.get_block_economic_state(block.block_hash)
          { id: block.id, proposal_reward: economic.miner_reward.proposal, commit_reward: economic.miner_reward.committed, created_at: block.created_at, updated_at: Time.current }
        end.compact

      Block.upsert_all(values) if values.present?
    end

    puts "done"
  end
end
