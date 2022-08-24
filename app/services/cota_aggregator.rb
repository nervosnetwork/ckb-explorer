class CotaAggregator 
  class Error < StandardError
    attr_reader :code, :message, :data
    def initialize(code, message, data)
      @code = code
      @message = message
      @data = data
    end
  end
  include Singleton
  attr_accessor :url
  def initialize(url=ENV['COTA_AGGREGATOR_URL'])
    @url = url
    @req_id = 0
  end

  def get_history_transactions(cota_id:, token_index:, page:nil, page_size:nil)
    send_request 'get_history_transactions', {
      cota_id: cota_id,
      token_index: '0x' + token_index.to_s(16),
      page: page,
      page_size: page_size
    }
  end

  def get_issuer_info(lock_script)
    send_request 'get_issuer_info', {
      lock_script: lock_script
    }
  end

  def get_define_info(cota_id)
    send_request 'get_define_info', {
      cota_id: cota_id
    }
  end
  
  def send_request(method, params)
    @req_id += 1
    payload = {
      jsonrpc: "2.0",
      id: @req_id,
      method: method, 
      params: params
    }
    res = HTTP.post(url, json: payload)
    data = JSON.parse res.to_s
    if err = data['error']
      raise Error.new(err['code'], err['message'], err['data'])
    else
      return data['result']
    end
  end
end
