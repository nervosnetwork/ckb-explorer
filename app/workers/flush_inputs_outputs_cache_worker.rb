class FlushInputsOutputsCacheWorker
  include Sidekiq::Worker

  def perform(block_id)
    block = Block.find_by(id: block_id)
    return if block.blank?

    block.cell_inputs.select(:id).find_in_batches do |cell_inputs|
      cache_keys = []
      cell_inputs.each do |cell_input|
        cache_keys << cell_input.cache_keys
      end
      $redis.pipelined do
        Rails.cache.delete_multi(cache_keys)
      end
    end
  end
end
