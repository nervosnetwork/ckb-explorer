require "test_helper"

module CkbSync
  class ApiTest < ActiveSupport::TestCase
    test "should contain related methods" do
      contained_method_names = %w(get_cellbase_output_capacity_details get_banned_addresses inspect genesis_block get_block_by_number genesis_block_hash get_block_hash rpc get_block dao_out_point dao_code_hash get_tip_block_number get_cells_by_lock_hash get_live_cell send_transaction get_tip_header local_node_info secp_group_out_point set_secp_group_dep get_current_epoch set_dao_dep get_peers get_transaction compute_transaction_hash get_peers_state tx_pool_info get_blockchain_info get_epoch_by_number calculate_dao_maximum_withdraw secp_cell_code_hash compute_script_hash get_lock_hash_index_states deindex_lock_hash secp_cell_type_hash dry_run_transaction get_transactions_by_lock_hash index_lock_hash get_live_cells_by_lock_hash get_header_by_number get_header set_ban).freeze
      sdk_api_names = CKB::API.instance_methods(false)

      assert_equal sdk_api_names.map(&:to_s).sort, contained_method_names.sort
    end
  end
end
