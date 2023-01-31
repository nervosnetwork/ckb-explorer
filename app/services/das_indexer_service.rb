class DasIndexerService
  include Singleton
  def initialize(endpoint = ENV.fetch("DAS_INDEXER_URL", "https://indexer-basic.da.systems/v1/"))
    @endpoint = endpoint
  end

  def reverse_record(ckb_address)
    addr = CkbUtils.parse_address(ckb_address)
    algo_id = addr.script.args[0, 4]
    return "" unless algo_id == "0x05"

    manager_addr = addr.script.args[-40..-1]
    res = HTTP.post(File.join(@endpoint, "reverse/record"),
                    json: {
                      "type": "blockchain",
                      "key_info": {
                        "coin_type": "",
                        "chain_id": "1",
                        "key": "0x#{manager_addr}"
                      }
                    })
    data = JSON.parse res.to_s
    case data["errno"]
    when 0
    when 20007
      return ""
    else
      raise data["errmsg"]
    end

    data["data"]["account"]
  end
end
