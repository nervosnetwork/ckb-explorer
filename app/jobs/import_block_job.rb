class ImportBlockJob < ApplicationJob
  class_attribute :transaction_processors
  def perform(block_hash, cycles: nil, force: false)
    self.transaction_processors ||= Concurrent::FixedThreadPool.new(5, fallback_policy: :caller_runs)
    case block_hash
    when Integer
      block = Block.fetch_raw_hash_by_number(block_hash)
      block_number = block_hash
      block_hash = block["header"]["hash"]
    when String
      block = Block.fetch_raw_hash(block_hash)
      block_number = block["header"]["number"].hex
    when Hash
      block = block_hash
      block_number = block["header"]["number"].hex
      Block.write_raw_hash_cache(block)
    end
    header = block["header"]
    puts "Epoch Info: #{CkbUtils.parse_epoch(header['epoch'].hex)}"

    block_record = Block.create_with(
      number: block_number,
      parent_hash: header["parent_hash"],
      version: header["version"].hex,
      timestamp: header["timestamp"].hex,
      transactions_root: header["transactions_root"],
      proposals_hash: header["proposals_hash"],
      extra_hash: header["uncles_hash"] || header[:extra_hash],
      proposals: block["proposals"],
      proposals_count: block["proposals"].size,
      ckb_transactions_count: block["transactions"].size,
      uncles_count: block["uncles"].size,
      uncle_block_hashes: block["uncles"],
      dao: header["dao"],
      status: "pending"
    ).find_or_create_by!(
      block_hash: header["hash"]
    )
    i = -1
    txs =
      block["transactions"].map do |tx|
        i += 1
        c = cycles.present? ? cycles[i].hex : nil
        tx = ImportTransactionJob.perform_now tx, { block_hash: block_hash, tx_index: i, cycles: c }
        {
          ckb_transaction_id: tx.id,
          block_id: block_record.id,
          tx_index: i
        }
      end
    # setup the relationship between blocks and transactions.
    # notice: certain transaction may be included in different blocks
    BlockTransaction.upsert_all txs, unique_by: [:block_id, :tx_index]

    reduce_changes
    apply_changes
  end

  # reduce all changes from transactions
  def reduce_changes
  end

  # apply the changes to states and make new snapshot
  def apply_changes
  end
end
