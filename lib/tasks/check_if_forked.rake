namespace :block_validator do
  desc "Check the validity of the blocks"

  task :check_if_forked, [:from , :to] => :environment do |_, args|
    from = args[:from]
    to = args[:to]

    if from.present? && to.present? && from.to_i >=0 && to.to_i >= 0 && from.to_i <= to.to_i
      from = args[:from].to_i
      target_block_number = to.to_i
    else
      from = 0
      local_tip_block = Block.recent.first
      target_block_number = local_tip_block.present? ? local_tip_block.number : 0
    end

    progress_bar = ProgressBar.create({
      total: target_block_number,
      format: "%e %B %p%% %c/%C"
    })

    puts "check block from: #{from} to: #{target_block_number}"

    result = (from..target_block_number).map do |number|
      local_block = Block.find_by(number: number)
      target_block = CkbSync::Api.instance.get_block_by_number(number)
      progress_bar.increment

      number if local_block.block_hash != target_block.header.hash
    end.compact

    puts "invalid block numbers : #{result.join(", ")}"
    puts "done."
  end
end


