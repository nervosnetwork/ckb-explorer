require "test_helper"

module CkbSync
  class ApiTest < ActiveSupport::TestCase
    test "should contain related methods" do
      contained_method_names = %w(system_script_code_hash inspect genesis_block get_block_by_number genesis_block_hash rpc system_script_out_point dao_out_point get_block dao_code_hash get_tip_block_number get_cells_by_lock_hash get_transaction set_system_script_cell send_transaction set_dao_cell get_live_cell get_current_epoch local_node_info get_tip_header system_script_cell get_block_hash compute_transaction_hash get_epoch_by_number get_peers tx_pool_info get_blockchain_info get_peers_state deindex_lock_hash dry_run_transaction calculate_dao_maximum_withdraw get_lock_hash_index_states get_live_cells_by_lock_hash index_lock_hash get_transactions_by_lock_hash get_header_by_number get_cellbase_output_capacity_details set_ban get_banned_addresses get_header).freeze
      sdk_api_names = CKB::API.instance_methods(false)

      assert_equal sdk_api_names.map(&:to_s).sort, contained_method_names.sort
    end
  end
end
