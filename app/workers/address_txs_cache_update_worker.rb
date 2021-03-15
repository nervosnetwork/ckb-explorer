class AddressTxsCacheUpdateWorker
  include Sidekiq::Worker
  sidekiq_options queue: "critical"

  def perform(block_id)
    address_txs_pair = Hash.new
    block = Block.find_by(id: block_id)
    return if block.blank?

    ckb_transactions = block.ckb_transactions.select(:id, :contained_address_ids)
    return if ckb_transactions.blank?

    ckb_transactions.each do |tx|
      tx.contained_address_ids.each do |id|
        if address_txs_pair[id].present?
          address_txs_pair[id] << tx.id
        else
          address_txs_pair[id] = [tx.id]
        end
      end
    end
    already_exist_pairs = address_txs_pair.reject { |key| !$redis.exists?("Address/txs/#{key}") }
    new_pairs = address_txs_pair.reject { |key| $redis.exists?("Address/txs/#{key}") }
    service = ListCacheService.new

    already_exist_pairs.each do |k, v|
      score_member_pairs =
        CkbTransaction.where(id: v).select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).find_each.map do |tx|
          [tx.id, tx.to_json]
        end

      service.write("Address/txs/#{k}", score_member_pairs, CkbTransaction) if score_member_pairs.present?
    end

    ActiveRecord::Base.uncached do
      new_pairs.each do |k, _|
        key = "Address/txs/#{k}"
        address = Address.find_by(id: k)
        if address.present?
          records_counter = RecordCounters::AddressTransactions.new(address)
          service.fetch(key, 1, CkbTransaction::DEFAULT_PAGINATES_PER, CkbTransaction, records_counter) do
            CkbTransaction.where("contained_address_ids @> array[?]::bigint[]", [k]).select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent
          end
          service.expire(key, 30)
        end
      end
    end
  end
end
