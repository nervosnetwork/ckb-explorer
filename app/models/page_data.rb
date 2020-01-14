class PageData
  attr_reader :records, :klass, :total_count, :page_size, :start

  def initialize(records:, klass:, total_count:, page_size:, start:)
    @records = records
    @klass = klass
    @total_count = total_count
    @page_size = page_size
    @start = start
  end

  def total_pages
    (total_count.to_f / limit_value).ceil
  end

  def current_page
    (offset_value / limit_value) + 1
  end

  def prev_page
    current_page - 1 unless first_page? || out_of_range?
  end

  def next_page
    current_page + 1 unless last_page? || out_of_range?
  end

  def first_page?
    current_page == 1
  end

  def last_page?
    current_page == total_pages
  end

  def out_of_range?
    current_page > total_pages
  end

  def limit_value
    if page_size > max_paginates_per
      max_paginates_per
    else
      page_size
    end
  end

  def offset_value
    start
  end

  def max_paginates_per
    klass::MAX_PAGINATES_PER
  end
end
