class ProcessBlockJob < ApplicationJob
  def perform(block_hash)
    if block_hash.is_a?(Integer)
      block = Block.fetch_raw_hash_by_number(block_hash)
      block_number = block_hash
      block_hash = block["header"]["hash"]
    else
      block = Block.fetch_raw_hash(block_hash)
      block_number = block["header"]["number"]
    end
    block["transactions"].each do |tx|
      ProcessTransactionJob.perform_later tx
    end
  end
end
