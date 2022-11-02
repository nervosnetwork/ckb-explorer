module CkbSync
  class Api
    include Singleton

    METHOD_NAMES = %w(system_script_out_point dry_run_transaction set_system_script_cell system_script_cell system_script_cell_hash genesis_block get_block_by_number genesis_block_hash get_block_hash get_block get_tip_header get_tip_block_number get_cells_by_lock_hash get_transaction get_live_cell local_node_info get_current_epoch get_epoch_by_number get_peers tx_pool_info get_blockchain_info get_peers_state compute_transaction_hash get_cellbase_output_capacity_details calculate_dao_maximum_withdraw compute_script_hash get_block_economic_state).freeze

    @@latest_json_rpc_id = 0

    def initialize
      @api = CKB::API.new(host: ENV["CKB_NODE_URL"], timeout_config: { open_timeout: 1, read_timeout: 3, write_timeout: 1 })
    end

    def chain_type
      get_blockchain_info.chain
    end

    def mode
      if chain_type == "ckb"
        CKB::MODE::MAINNET
      else
        CKB::MODE::TESTNET
      end
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

    METHOD_NAMES.each do |name|
      define_method name do |*params|
        call_rpc(name, params: params)
      end
    end

    def generate_json_rpc_id
      @@latest_json_rpc_id += 1
      return @@latest_json_rpc_id
    end

    # in case that some method you call is not implemented in ruby sdk
    # options:
    #   method: the method you call ,e.g. `get_transaction`
    #   params: parameters of this method, is an array, e.g. `["0xa1b2x3"]`
    # return:
    #   parsed json,  e.g. `{"jsonrpc":"2.0","result":"0x1842749a5c0","id":1}`
    def directly_single_call_rpc options

      payload = {
        "id": generate_json_rpc_id,
        "jsonrpc": "2.0",
        "method": options[:method],
        "params": options[:params]
      }

      url = ENV['CKB_NODE_URL']
      res = HTTP.post(url, json: payload)
      result = JSON.parse res.to_s

      return result
    end

    def call_rpc(method, params: [])
      @api.send(method, *params)
    end
  end
end
