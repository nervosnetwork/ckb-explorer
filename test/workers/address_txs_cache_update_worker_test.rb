require "test_helper"

class AddressTxsCacheUpdateWorkerTest < ActiveSupport::TestCase
  setup do
    redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
    Rails.stubs(:cache).returns(redis_cache_store)
    Rails.cache.extend(CacheRealizer)
  end

  test "address_txs_cache_update_worker should add new cache when there are records for the address" do
    Sidekiq::Testing.inline!
    block = create(:block, :with_block_hash)
    addr = create(:address)
    500.times.each do |i|
      create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + i)
    end
    addr.update(ckb_transactions_count: addr.custom_ckb_transactions.count)
    s = ListCacheService.new
    records_counter = RecordCounters::AddressTransactions.new(addr)
    s.fetch(addr.tx_list_cache_key, 1, 20, CkbTransaction, records_counter) do
      addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent
    end
    tx = create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + 1000)
    AddressTxsCacheUpdateWorker.perform_async(block.id)
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
    AddressTxsCacheUpdateWorker.perform_async(block.id)
    assert $redis.ttl(addr.tx_list_cache_key) <= 30
  end
end
