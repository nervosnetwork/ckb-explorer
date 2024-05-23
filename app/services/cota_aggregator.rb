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

  def initialize(url = ENV["COTA_AGGREGATOR_URL"])
    @url = url
    @req_id = 0
  end

  # {"indexer_block_number":9939607,"is_mainnet":true,"node_block_number":9939607,"syncer_block_number":9939607,"version":"v0.7.2"}
  def get_aggregator_info
    send_request "get_aggregator_info", []
  end

  # token_index force 4 bytes
  def get_history_transactions(cota_id:, token_index:, page: nil, page_size: nil)
    send_request "get_history_transactions", {
      cota_id:,
      token_index: "0x" + token_index.to_s(16).rjust(8, "0"),
      page:,
      page_size:,
    }
  end

  def get_issuer_info(lock_script)
    send_request "get_issuer_info", {
      lock_script:,
    }
  end

  def get_define_info(cota_id)
    send_request "get_define_info", {
      cota_id:,
    }
  end

  def get_issuer_info_by_cota_id(cota_id)
    send_request "get_issuer_info_by_cota_id", {
      cota_id:,
    }
  end

  def is_claimed(lock_script:, cota_id:, token_index:)
    send_request "is_claimed", {
      cota_id:,
      lock_script:,
      token_index: "0x" + token_index.to_s(16),
    }
  end

  def get_mint_cota_nft(lock_script:, page: nil, page_size: nil)
    send_request "is_claimed", {
      lock_script:,
      page:,
      page_size:,
    }
  end

  def get_cota_nft_sender(lock_script:, cota_id:, token_index:)
    send_request "get_cota_nft_sender", {
      cota_id:,
      lock_script:,
      token_index: "0x" + token_index.to_s(16),
    }
  end

  def get_transactions_by_block_number(block_number)
    send_request "get_transactions_by_block_number", {
      block_number: block_number.to_s,
    }
  end

  def send_request(method, params)
    @req_id += 1
    payload = {
      jsonrpc: "2.0",
      id: @req_id,
      method:,
      params:,
    }
    res = HTTP.post(url, json: payload)
    data = JSON.parse res.to_s
    if err = data["error"]
      raise Error.new(err["code"], err["message"], err["data"])
    else
      data["result"]
    end
  end
end
