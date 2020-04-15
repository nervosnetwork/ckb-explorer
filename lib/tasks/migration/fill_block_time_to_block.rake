class FillBlockTimeToBlock
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_block_time_to_block"
      task fill_block_time_to_block: :environment do
        Block.find_by(number: 0).update(block_time: 0)
        Block.where.not(number: 0).order(:number).find_in_batches do |blocks|
          blocks_arry = blocks.to_a
          new_blocks =
            blocks_arry.each_with_index.map do |block, index|
              if index.zero?
                target_block = Block.find_by(number: block.number - 1)
                block_time = block.timestamp - target_block.timestamp
              else
                block_time = block.timestamp - blocks_arry[index - 1].timestamp
              end

              { id: block.id, created_at: block.created_at, updated_at: Time.current, block_time: block_time }
            end

          Block.upsert_all(new_blocks)
        end
      end
    end
  end

  private

end

FillBlockTimeToBlock.new
