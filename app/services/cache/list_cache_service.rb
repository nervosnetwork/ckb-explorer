module Cache
	class ListCacheService
		# given block must return score_member_pairs [[1, "a"], [2, "c"]]
		def fetch(key, page, page_size)
			start, stop = get_range(page, page_size)
			rs = $redis.zrevrange(key, start, stop)
			return rs if rs.present?

			if block_given?
				ActiveRecord::Base.with_advisory_lock("list/cache/#{key}/#{page}/#{page_size}", timeout_seconds: 3) do
					rs = $redis.zrevrange(key, start, stop)
					return rs if rs.present?

					score_member_pairs = yield
					return if score_member_pairs.blank?

					write(key, score_member_pairs)
					return $redis.zrevrange(key, start, stop)
				end
			end
		end

		def write(key, score_member_pairs)
			$redis.zadd(key, score_member_pairs)
		end

		private

		def get_range(page, page_size)
			if page == 1
				return 0, page_size
			else
				start = (page - 1) * page_size - 1
				stop = start + page_size
				return start, stop
			end
		end
	end
end