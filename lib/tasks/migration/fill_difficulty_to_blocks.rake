namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_difficulty_to_blocks"
  task fill_difficulty_to_blocks: :environment do
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    Block.where(difficulty: nil).select(:id, :compact_target).find_in_batches do |blocks|
      attrs =
        blocks.map do |block|
          { id: block.id, difficulty: CkbUtils.compact_to_difficulty(block.compact_target) }
        end
      Block.upsert_all(attrs, unique_by: :id, update_only: :difficulty)
    end

    UncleBlock.where(difficulty: nil).select(:id, :block_hash, :block_id, :compact_target).find_in_batches do |uncle_blocks|
      attrs =
        uncle_blocks.map do |uncle_block|
          { block_hash: uncle_block.block_hash, block_id: uncle_block.block_id, difficulty: CkbUtils.compact_to_difficulty(uncle_block.compact_target) }
        end
      UncleBlock.upsert_all(attrs, unique_by: %i[block_hash block_id], update_only: :difficulty)
    end

    puts "done"
  end
end
