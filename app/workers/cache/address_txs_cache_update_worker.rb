module Cache
  class AddressTxsCacheUpdateWorker
    include Sidekiq::Worker
    sidekiq_options queue: "critical"

    def perform(address_txs_pair)
      already_exist_pairs = address_txs_pair.reject { |key| !$redis.exists?("Address/txs/#{key}") }
      new_pairs = address_txs_pair.reject { |key| $redis.exists?("Address/txs/#{key}") }
      service = Cache::ListCacheService.new

      already_exist_pairs.each do |k, v|
        score_member_pairs =
          CkbTransaction.where(id: v).select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).map do |tx|
            [tx.id, tx.to_json]
          end

        service.write("Address/txs/#{k}", score_member_pairs, CkbTransaction)
      end

      new_pairs.each do |k, _|
        key = "Address/txs/#{k}"
        service.fetch(key, 1, CkbTransaction::DEFAULT_PAGINATES_PER, CkbTransaction) do
          CkbTransaction.where("contained_address_ids @> array[?]::bigint[]", [k]).select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent
        end
        service.expire(key, 30)
      end
    end
  end
end
