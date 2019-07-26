require "test_helper"

module CkbSync
  class ApiTest < ActiveSupport::TestCase
    test "should contain related methods" do
      contained_method_names = %w(system_script_code_hash inspect genesis_block get_block_by_number genesis_block_hash rpc system_script_out_point get_block_hash get_block get_tip_header get_tip_block_number set_system_script_cell get_transaction get_live_cell system_script_cell local_node_info get_current_epoch get_cells_by_lock_hash get_peers tx_pool_info send_transaction get_blockchain_info compute_transaction_hash get_epoch_by_number get_peers_state calculate_dao_maximum_withdraw dry_run_transaction get_live_cells_by_lock_hash deindex_lock_hash get_lock_hash_index_states get_transactions_by_lock_hash index_lock_hash get_header get_header_by_number get_cellbase_output_capacity_details set_ban get_banned_addresses).freeze
      sdk_api_names = CKB::API.instance_methods(false)

      assert_equal sdk_api_names.map(&:to_s).sort, contained_method_names.sort
    end
  end
end
