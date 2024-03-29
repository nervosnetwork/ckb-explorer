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
    data = JSON.parse(res.to_s)
    if data["err_no"] == 0
      return data["data"]["account"]
    else
      err_msg = data["err_msg"]
      Rails.logger.info "das service response error: #{err_msg}, address: #{ckb_address}"
      return ""
    end
  end
end
