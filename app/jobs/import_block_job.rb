class ImportBlockJob < ApplicationJob
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
      ImportTransactionJob.perform_later tx, { block_hash: block["hash"] }
    end
  end
end
