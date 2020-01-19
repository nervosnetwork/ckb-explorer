class AddressCkbTransactionsCacheFlusher
  include Sidekiq::Worker

  def perform(block_id)
    $redis.with do |conn|
      forked_block = ForkedBlock.find_by(id: block_id)
      cache_keys = Address.where(id: forked_block.address_ids).map(&:ckb_transaction_cache_key)
      cache_keys.each_slice(500) do |keys|
        conn.pipelined do
          conn.del(keys)
        end
      end
    end
  end
end
