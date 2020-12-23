require "test_helper"

module Cache
	class ListCacheServiceTest < ActiveSupport::TestCase
		setup do
			redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
			Rails.stubs(:cache).returns(redis_cache_store)
			Rails.cache.extend(CacheRealizer)
		end

		test "fetch function should return the corresponding result when the key is exist" do
			block = create(:block, :with_block_hash)
			addr = create(:address)
			20.times.each do |i|
				create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + i)
			end
			txs = addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent
			tx_jsons = []
			score_member_pairs = txs.map do |tx|
				tx_jsons << tx.to_json
				[tx.id, tx.to_json]
			end
			$redis.zadd(addr.tx_list_cache_key, score_member_pairs)
			s = Cache::ListCacheService.new
			rs = s.fetch(addr.tx_list_cache_key, 1, 20, CkbTransaction)
			expected_rs = tx_jsons.map do |json|
				CkbTransaction.new.from_json(json)
			end
			assert_equal expected_rs, rs
		end

		test "fetch function should return the corresponding result when block is given" do
			block = create(:block, :with_block_hash)
			addr = create(:address)
			20.times.each do |i|
				create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + i)
			end
			$redis.flushdb
			s = Cache::ListCacheService.new
			tx_jsons = []
			rs = s.fetch(addr.tx_list_cache_key, 1, 20, CkbTransaction) do
				txs = addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent
				txs.map do |tx|
					tx_jsons << tx.to_json
					[tx.id, tx.to_json]
				end
				txs
			end
			expected_rs = tx_jsons.map do |json|
				CkbTransaction.new.from_json(json)
			end
			assert_equal expected_rs, rs
		end

		test "write function should add records to cache" do
			block = create(:block, :with_block_hash)
			addr = create(:address)
			20.times.each do |i|
				create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + i)
			end
			txs = addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent
			tx_jsons = []
			score_member_pairs = txs.map do |tx|
				tx_jsons << tx.to_json
				[tx.id, tx.to_json]
			end
			s = Cache::ListCacheService.new
			s.write(addr.tx_list_cache_key, score_member_pairs, CkbTransaction)
			rs = s.fetch(addr.tx_list_cache_key, 1, 20, CkbTransaction)
			expected_rs = tx_jsons.map do |json|
				CkbTransaction.new.from_json(json)
			end
			assert_equal expected_rs, rs
		end

		test "write function will remove exceeds max cache count records" do
			block = create(:block, :with_block_hash)
			addr = create(:address)
			500.times.each do |i|
				create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + i)
			end
			txs = addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent
			score_member_pairs = txs.map do |tx|
				[tx.id, tx.to_json]
			end
			s = Cache::ListCacheService.new
			s.write(addr.tx_list_cache_key, score_member_pairs, CkbTransaction)
			tx_ids = []
			100.times.each do |i|
				tx = create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + i)
				tx_ids << tx.id
			end
			txs = addr.custom_ckb_transactions.where(id: tx_ids).select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent
			score_member_pairs = txs.map do |tx|
				[tx.id, tx.to_json]
			end
			s.write(addr.tx_list_cache_key, score_member_pairs, CkbTransaction)

			assert_equal 400, $redis.zcard(addr.tx_list_cache_key)
		end

		test "zrem should remove specific members associate with the key" do
			block = create(:block, :with_block_hash)
			addr = create(:address)
			20.times.each do |i|
				create(:ckb_transaction, :with_single_output, block: block, contained_address_ids: [addr.id], block_timestamp: Time.current.to_i + i)
			end
			txs = addr.custom_ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent
			tx_jsons = []
			score_member_pairs = txs.map do |tx|
				tx_jsons << tx.to_json
				[tx.id, tx.to_json]
			end
			$redis.zadd(addr.tx_list_cache_key, score_member_pairs)
			assert_equal 20, $redis.zcard(addr.tx_list_cache_key)

			s = Cache::ListCacheService.new
			s.zrem(addr.tx_list_cache_key, tx_jsons[0..3])
			assert_equal 16, $redis.zcard(addr.tx_list_cache_key)
			assert_equal tx_jsons[4..], $redis.zrevrange(addr.tx_list_cache_key, 0, -1)
		end
	end
end
