require "test_helper"

module CkbSync
  class ApiTest < ActiveSupport::TestCase
    test "should contain related methods" do
      contained_method_names = %w(secp_group_out_point secp_code_out_point secp_data_out_point secp_cell_code_hash dao_out_point dao_code_hash multi_sign_secp_cell_type_hash multi_sign_secp_group_out_point set_secp_group_dep set_dao_dep sync_state get_block get_tip_header get_tip_block_number get_transaction get_live_cell _compute_transaction_hash _compute_script_hash local_node_info get_current_epoch get_epoch_by_number secp_cell_type_hash get_peers tx_pool_info get_block_economic_state get_blockchain_info get_peers_state dry_run_transaction calculate_dao_maximum_withdraw get_header_by_number get_cellbase_output_capacity_details set_ban get_banned_addresses get_block_template submit_block clear_tx_pool get_raw_tx_pool get_consensus set_network_active add_node remove_node ping_peers get_transaction_proof verify_transaction_proof clear_banned_addresses get_header genesis_block get_block_by_number genesis_block_hash get_block_hash send_transaction batch_request inspect dao_type_hash rpc).freeze
      sdk_api_names = CKB::API.instance_methods(false)

      assert_equal contained_method_names.sort, sdk_api_names.map(&:to_s).sort
    end

    test "the API being used should be available" do
      api_names = %w(get_block_by_number local_node_info get_cellbase_output_capacity_details get_tip_block_number get_blockchain_info get_current_epoch get_epoch_by_number)
      sdk_api_names = CKB::API.instance_methods(false).map(&:to_s)

      assert_empty api_names - sdk_api_names
    end
  end
end
