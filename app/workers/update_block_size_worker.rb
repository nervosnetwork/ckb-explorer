class UpdateBlockSizeWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low"

  def perform(block_id)
    block = Block.find_by(id: block_id)
    return if block.blank?

    node_block = CkbSync::Api.instance.get_block_by_number(block.number)
    block.update(block_size: node_block.serialized_size_without_uncle_proposals)
  end
end
