namespace :migration do
  task update_block_reward: :environment do
    current_epoch_number = Block.maximum(:epoch).to_i
    (0..current_epoch_number).each do |epoch|
      Block.where(epoch: epoch).each do |block|
        block.update(reward: CkbUtils.base_reward(block.number, epoch))
      end
    end

    puts "done"
  end
end
