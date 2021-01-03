class ListCacheService
  MAX_CACHED_PAGE = 10

  def initialize(max_cached_page = MAX_CACHED_PAGE)
    @max_cached_page = max_cached_page
  end

  # given block must return ActiveRecord_Relation, if there are no records will return empty array
  def fetch(key, page, page_size, record_klass, records_counter)
    page, page_size = process_page_params(page, page_size, record_klass)
    return [] if exceeds_max_pages?(page, page_size, records_counter)

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

  def write(key, score_member_pairs, record_klass)
    # cache at most max_cached_page * record_klass::MAX_PAGINATES_PER + record_klass::MAX_PAGINATES_PER records
    $redis.zadd(key, score_member_pairs)
    adjust_buffer_capacity(key, record_klass) unless skip_buffer_adjustment(key)
  end

  def expire(key, second)
    $redis.expire(key, second)
  end

  def zrem(key, member)
    $redis.zrem(key, member)
  end

  def set_skip_buffer_keys(keys)
    $redis.sadd("skip_buffer_aj_keys", keys)
  end

  private

  def exceeds_max_pages?(page, page_size, records_counter)
    page > (records_counter.total_count / page_size).ceil
  end

  attr_reader :max_cached_page

  def process_page_params(page, page_size, record_klass)
    page = page.to_i
    page_size = page_size.to_i
    if page_size > record_klass::MAX_PAGINATES_PER
      page_size = record_klass::MAX_PAGINATES_PER
    end

    return page, page_size
  end

  def skip_buffer_adjustment(key)
    $redis.sismember("skip_buffer_aj_keys", key)
  end

  def adjust_buffer_capacity(key, record_klass)
    total_count = $redis.zcard(key)
    if total_count > max_cache_count(record_klass)
      $redis.zremrangebyrank(key, 0, total_count - max_cached_page * record_klass::MAX_PAGINATES_PER - 1)
    end
  end

  def max_cache_count(record_klass)
    max_cached_page * record_klass::MAX_PAGINATES_PER + record_klass::MAX_PAGINATES_PER
  end

  def load_records(key, page, page_size, records, record_klass)
    # load first max_cached_page records
    if page < max_cached_page
      start, stop = get_range(page, page_size)
      score_member_pairs =
        records.limit(max_cached_page * record_klass::MAX_PAGINATES_PER).map do |record|
          [record.id, record.to_json]
        end
      write(key, score_member_pairs, record_klass) if score_member_pairs.present?
      rs = read_records(key, start, stop, record_klass)
      if rs.present?
        return rs
      else
        return []
      end
    else
      # Do not cache parts that exceed the maximum number of cached pages, Optimize this when there is more pressure
      records.page(page).per(page_size)
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
