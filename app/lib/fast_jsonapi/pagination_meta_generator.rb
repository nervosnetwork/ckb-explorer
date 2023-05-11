module FastJsonapi
  class PaginationMetaGenerator
    DEFAULT_PAGE = 1
    DEFAULT_PER_PAGE = 20

    def initialize(request:, records:, page:, page_size:, records_counter: nil)
      @url = request.base_url + request.path + query_string(request.query_parameters)
      @page = page.to_i
      @page_size = limit_page_size(records, page_size.to_i)
      @records = records
      @records_counter = records_counter || records
      @total_count = @records_counter.total_count.to_i
      @total_pages = total_pages
      @hash = { links: {}, meta: { total: @total_count, page_size: @page_size } }
    end

    def total_pages
      (total_count / @page_size).ceil
    end

    def call
      hash
    end

    private

    attr_reader :page, :page_size, :records, :records_counter, :total_count
    attr_accessor :url, :hash

    def current_page
      records.current_page
    end

    def last_page?
      current_page == total_pages
    end

    def next_page
      current_page + 1 unless last_page? || out_of_range?
    end

    def last_page?
      current_page == total_pages
    end

    def out_of_range?
      current_page > total_pages
    end

    def generate_url(page)
      [url, url_params(page)].join("?")
    end

    def url_params(page)
      url_params = {}
      url_params[:page_size] = page_size if include_per_page?
      url_params[:page] = page if include_page?(page)
      url_params.to_query
    end

    def include_per_page?
      (page_size != 0) && (page_size != DEFAULT_PER_PAGE)
    end

    def include_page?(page)
      (page != 0) && (page != DEFAULT_PAGE)
    end

    def query_string(query_params)
      query_params.reject { |key| key.in?(%w(page page_size)) }.map { |k, v| "?#{k}=#{v}" }.join("?")
    end

    def limit_page_size(records, page_size)
      if @ckb_transactions.try(:klass).present?
        if page_size > records.klass::MAX_PAGINATES_PER
          records.klass::MAX_PAGINATES_PER
        else
          page_size
        end
      else
        return DEFAULT_PER_PAGE if records.blank?

        if page_size > records.first.class::MAX_PAGINATES_PER
          DEFAULT_PER_PAGE
        else
          page_size
        end
      end
    end
  end
end
