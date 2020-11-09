require "test_helper"

module CkbSync
  class ApiTest < ActiveSupport::TestCase
    test "should contain related methods" do
      contained_method_names = %w(_compute_script_hash _compute_transaction_hash add_node batch_request calculate_dao_maximum_withdraw clear_banned_addresses clear_tx_pool dao_code_hash dao_out_point dao_type_hash dry_run_transaction genesis_block genesis_block_hash get_banned_addresses get_block get_block_by_number get_block_economic_state get_block_hash get_block_template get_blockchain_info get_cellbase_output_capacity_details get_current_epoch get_epoch_by_number get_header get_header_by_number get_live_cell get_peers get_peers_state get_tip_block_number get_tip_header get_transaction get_transaction_proof inspect local_node_info multi_sign_secp_cell_type_hash multi_sign_secp_group_out_point ping_peers remove_node rpc secp_cell_code_hash secp_cell_type_hash secp_code_out_point secp_data_out_point secp_group_out_point send_transaction set_ban set_dao_dep set_network_active set_secp_group_dep submit_block sync_state tx_pool_info verify_transaction_proof).freeze
      sdk_api_names = CKB::API.instance_methods(false)

      assert_equal contained_method_names.sort, sdk_api_names.map(&:to_s).sort
    end
  end
end
