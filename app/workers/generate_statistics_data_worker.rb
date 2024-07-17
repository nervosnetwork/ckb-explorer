class GenerateStatisticsDataWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3

  def perform(block_id)
    block = Block.find(block_id)
    node_block = CkbSync::Api.instance.get_block_by_number(block.number)
    block_size = node_block.serialized_size_without_uncle_proposals
    block.update(block_size:)

    # update largest block information in epoch stats
    epoch_stats = EpochStatistic.find_by epoch_number: block.epoch

    if epoch_stats && epoch_stats.largest_block_size.to_i < block_size
      epoch_stats.update(largest_block_size: block_size, largest_block_number: block.number)
    end
  end
end
