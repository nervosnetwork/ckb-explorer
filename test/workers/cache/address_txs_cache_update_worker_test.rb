require "test_helper"

module Cache
  class AddressTxsCacheUpdateWorkerTest < ActiveSupport::TestCase
    setup do
      redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
      Rails.stubs(:cache).returns(redis_cache_store)
      Rails.cache.extend(CacheRealizer)
    end

    test "address_txs_cache_update_worker should cache address fist 30 page txs when there are no records for the address" do
      Sidekiq::Testing.inline!
      block = create(:block, :with_block_hash)
      addr = create(:address)
      500.times.each do |i|
        create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + i)
      end
      address_txs = { addr.id => addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.pluck(:id) }
      Cache::AddressTxsCacheUpdateWorker.perform_async(address_txs)
      max_count = Cache::ListCacheService::MAX_CACHED_PAGE * CkbTransaction::DEFAULT_PAGINATES_PER
      expected_txs = addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.limit(max_count).map(&:to_json)
      assert_equal max_count, $redis.zcard(addr.tx_list_cache_key)
      assert_equal expected_txs, $redis.zrevrange(addr.tx_list_cache_key, 0, -1)
    end

    test "address_txs_cache_update_worker should add new cache when there are records for the address" do
      Sidekiq::Testing.inline!
      block = create(:block, :with_block_hash)
      addr = create(:address)
      500.times.each do |i|
        create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + i)
      end
      s = Cache::ListCacheService.new
      s.fetch(addr.tx_list_cache_key, 1, 20, CkbTransaction) do
        addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent
      end
      tx = create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + 1000)
      address_txs = { addr.id => [tx.id] }
      Cache::AddressTxsCacheUpdateWorker.perform_async(address_txs)
      expected_txs = addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.first.to_json

      assert_equal [expected_txs], $redis.zrevrange(addr.tx_list_cache_key, 0, 0)
    end

    test "new cache should expired after 30 seconds" do
      Sidekiq::Testing.inline!
      block = create(:block, :with_block_hash)
      addr = create(:address)
      500.times.each do |i|
        create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + i)
      end
      address_txs = { addr.id => addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.pluck(:id) }
      Cache::AddressTxsCacheUpdateWorker.perform_async(address_txs)
      assert $redis.ttl(addr.tx_list_cache_key) <= 30
    end
  end
end
