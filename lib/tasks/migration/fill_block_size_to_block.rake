class BlockSizeCalculator
  include Concurrent::Async

  def initialize(api, blocks)
    super()
    @api = api
    @blocks = blocks
  end

  def calculate_block_size
    blocks_arry = @blocks.to_a
    new_blocks =
      blocks_arry.map do |block|
        block_number = block.number
        puts "number: #{block_number}"
        node_block = @api.get_block_by_number(block_number)

        { id: block.id, created_at: block.created_at, updated_at: Time.current, block_size: node_block.serialized_size_without_uncle_proposals }
      end

    Block.upsert_all(new_blocks)
  end
end
class FillBlockSizeToBlock
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_block_size_to_block"
      task fill_block_size_to_block: :environment do
        api = CkbSync::Api.instance
        Block.where(block_size: nil).order(:number).find_in_batches(batch_size: 3000) do |blocks|
          calculators = []
          blocks.each_slice(1000) do |items|
            calculator = BlockSizeCalculator.new(api, items)
            calculators << calculator.async.calculate_block_size
          end

          loop do
            if calculators.all? { |calculator| calculator.fulfilled? }
              break
            else
              sleep(0.5)
            end
          end
        end
      end
    end
  end
end

FillBlockSizeToBlock.new
