module CkbSync
  class Api
    include Singleton

    METHOD_NAMES = %w(
      system_script_out_point dry_run_transaction set_system_script_cell system_script_cell
      system_script_cell_hash genesis_block get_block_by_number genesis_block_hash get_block_hash get_block get_tip_header get_tip_block_number get_cells_by_lock_hash get_transaction get_live_cell local_node_info get_current_epoch get_epoch_by_number get_peers tx_pool_info get_blockchain_info get_peers_state compute_transaction_hash get_cellbase_output_capacity_details calculate_dao_maximum_withdraw compute_script_hash get_block_economic_state batch_request
    ).freeze

    @@latest_json_rpc_id = 0

    def initialize
      @api = CKB::API.new(host: ENV["CKB_NODE_URL"],
                          timeout_config: {
                            open_timeout: 1, read_timeout: 3,
                            write_timeout: 1
                          })
    end

    def chain_type
      get_blockchain_info.chain
    end

    def mode
      # if chain_type == "ckb"
      #   CKB::MODE::MAINNET
      # else
      #   CKB::MODE::TESTNET
      # end

      ENV["CKB_NET_MODE"]
    end

    def issuer_script_code_hash
      if mode == CKB::MODE::MAINNET
        Settings.mainnet_issuer_script_code_hash
      else
        Settings.testnet_issuer_script_code_hash
      end
    end

    def token_class_script_code_hash
      if mode == CKB::MODE::MAINNET
        Settings.mainnet_token_class_script_code_hash
      else
        Settings.testnet_token_class_script_code_hash
      end
    end

    def token_script_code_hash
      if mode == CKB::MODE::MAINNET
        Settings.mainnet_token_script_code_hash
      else
        Settings.testnet_token_script_code_hash
      end
    end

    def cota_registry_code_hash
      if mode == CKB::MODE::MAINNET
        Settings.mainnet_cota_registry_code_hash
      else
        Settings.testnet_cota_registry_code_hash
      end
    end

    def cota_regular_code_hash
      if mode == CKB::MODE::MAINNET
        Settings.mainnet_cota_regular_code_hash
      else
        Settings.testnet_cota_regular_code_hash
      end
    end

    def spore_cluster_code_hashes
      if mode == CKB::MODE::MAINNET
        [Settings.spore_cluster1_code_hash]
      else
        [Settings.spore_cluster1_code_hash, Settings.spore_cluster2_code_hash, Settings.spore_cluster3_code_hash]
      end
    end

    def spore_cell_code_hashes
      if mode == CKB::MODE::MAINNET
        [Settings.spore_cell1_code_hash]
      else
        [Settings.spore_cell1_code_hash, Settings.spore_cell2_code_hash, Settings.spore_cell3_code_hash]
      end
    end

    def did_cell_code_hash
      Settings.did_cell_code_hash
    end

    def omiga_inscription_info_code_hash
      Settings.omiga_inscription_info_code_hash
    end

    def omiga_inscription_code_hash
      Settings.omiga_inscription_code_hash
    end

    def xudt_code_hash
      Settings.xudt_code_hash
    end

    def xudt_compatible_code_hash
      Settings.xudt_compatible_code_hash
    end

    def unique_cell_code_hash
      Settings.unique_cell_code_hash
    end

    def rgbpp_code_hash
      Settings.rgbpp_code_hash
    end

    def btc_time_code_hash
      Settings.btc_time_code_hash
    end

    def single_use_lock_code_hash
      Settings.single_use_lock_code_hash
    end

    METHOD_NAMES.each do |name|
      define_method name do |*params|
        call_rpc(name, params:)
      end
    end

    def get_block_cycles(block_hash)
      data_with_cycles = CkbSync::Api.instance.directly_single_call_rpc method: "get_block",
                                                                        params: [
                                                                          block_hash, "0x0", true
                                                                        ]
      data_with_cycles["result"]["cycles"]
    end

    def generate_json_rpc_id
      @@latest_json_rpc_id += 1
      @@latest_json_rpc_id
    end

    # in case that some method you call is not implemented in ruby sdk
    # options:
    #   method: the method you call ,e.g. `get_transaction`
    #   params: parameters of this method, is an array, e.g. `["0xa1b2x3"]`
    # return:
    #   parsed json,  e.g. `{"jsonrpc":"2.0","result":"0x1842749a5c0","id":1}`
    def directly_single_call_rpc(options)
      payload = {
        "id": generate_json_rpc_id,
        "jsonrpc": "2.0",
        "method": options[:method],
        "params": options[:params],
      }

      url = ENV["CKB_NODE_URL"]

      # Rails.logger.debug "== in directly_call_rpc, url: #{url}, payload: #{payload}"

      res = HTTP.post(url, json: payload)
      JSON.parse res.to_s
      # Rails.logger.debug "== in directly_call_rpc result: #{result.inspect}"
    end

    # in case that some method you call is not implemented in ruby sdk
    # payload:
    #  [
    #      {
    #          "id": 3, "jsonrpc": "2.0", "method": "get_transaction", "params": ["0xed2049c21ffccfcd26281d60f8f77ff117adb9df9d3f8cbe5fe86e893c66d359"]
    #      },
    #      {
    #          "id": 4, "jsonrpc": "2.0", "method": "get_transaction", "params": ["0x6c80c63f956583569b1f8222c5846edc18fbb19757671b47a4e35cb98782804e"]
    #      }
    #  ]
    # return:
    #   parsed json
    #   `[
    #      {"jsonrpc":"2.0","result":"0x16e8100f3fe","id":4996},
    #      {"jsonrpc":"2.0","result":"0x16e81010c18","id":4997}
    #    ]`
    def directly_batch_call_rpc(payload)
      url = ENV["CKB_NODE_URL"]
      Rails.logger.debug "== in directly_batch_call_rpc, url: #{url}, payload: #{payload}"

      res = HTTP.post(url, json: payload)
      result = JSON.parse res.to_s
      Rails.logger.debug "== in directly_batch_call_rpc result: #{result.inspect}"

      result
    end

    # this methods calls the ruby-sdk, but not directly from rpc
    # some of the method is missing, e.g. get_block_median_time
    def call_rpc(method, params: [])
      @api.send(method, *params)
    end
  end
end
