class DasIndexerService
  include Singleton
  def initialize(endpoint=ENV.fetch('DAS_INDEXER_URL', 'https://indexer-basic.da.systems/v1/'))
    @endpoint = endpoint
  end

  def reverse_record(ckb_address)
    addr = CkbUtils.parse_address(ckb_address)
    eth_addr = addr.script.args[-40..-1]
    res = HTTP.post(File.join(@endpoint, 'reverse/record'), 
      json: {
        "type": "blockchain",
        "key_info":{
          "coin_type": "",
          "chain_id": "1",
          "key": "0x#{eth_addr}"
          }
        }
    )
    data = JSON.parse res.to_s
    if data['errno'] != 0
      raise data['errmsg']
    end
    data['data']['account']
  end
end
