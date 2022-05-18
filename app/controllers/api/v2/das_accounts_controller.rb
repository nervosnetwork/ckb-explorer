module Api::V2
  class DasAccountsController < BaseController
    def query
      das = DasIndexerService.instance

      cache_keys = params[:addresses]

      res = Rails.cache.read_multi(*cache_keys)
      not_cached = cache_keys - res.keys
      to_cache = {}
      not_cached.each do |address|
        name = das.reverse_record(address)
        res[address] = name
        to_cache[address] = name
      end
      Rails.cache.write_multi(to_cache, expires_in: 1.hour)
      render json: res
    end
  end
end
