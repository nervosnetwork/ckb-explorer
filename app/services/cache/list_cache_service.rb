module Cache
	class ListCacheService
		MAX_CACHED_PAGE = 10
		# given block must return ActiveRecord_Relation, if there are no records will return empty array
		def fetch(key, page, page_size, record_klass)
			page = page.to_i
			page_size = page_size.to_i
			start, stop = get_range(page, page_size)
			rs = read_records(key, start, stop, record_klass)
			return rs if rs.present?

			if block_given?
				ActiveRecord::Base.with_advisory_lock("list/cache/#{key}/#{page}/#{page_size}", timeout_seconds: 3) do
					rs = read_records(key, start, stop, record_klass)
					return rs if rs.present?

					records = yield
					return [] if records.blank?

					load_records(key, page, page_size, records, record_klass)
				end
			end
		end

		def write(key, score_member_pairs)
			$redis.zadd(key, score_member_pairs)
		end

		private

		def load_records(key, page, page_size, records, record_klass)
			# load first MAX_CACHED_PAGE records
			if page < MAX_CACHED_PAGE
				start, stop = get_range(page, page_size)
				score_member_pairs = records.limit(MAX_CACHED_PAGE * page_size).map do |record|
					[record.id, record.to_json]
				end
				write(key, score_member_pairs)
				rs = read_records(key, start, stop, record_klass)
				if rs.present?
					return rs
				else
					return []
				end
			else
				# Do not cache parts that exceed the maximum number of cached pages, Optimize this when there is more pressure
				records.page(@page).per(@page_size)
			end
		end

		def read_records(key, start, stop, record_klass)
			rs = $redis.zrevrange(key, start, stop)
			if rs.present?
				rs.map do |json|
					record_klass.new.from_json(json)
				end
			end
		end

		def get_range(page, page_size)
			if page == 1
				return 0, page_size - 1
			else
				start = (page - 1) * page_size
				stop = (page - 1) * page_size + page_size - 1
				return start, stop
			end
		end
	end
end