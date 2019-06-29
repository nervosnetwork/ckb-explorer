require "test_helper"

module CkbSync
  class ApiTest < ActiveSupport::TestCase
    test "should contain related methods" do
      contained_method_names = %w(system_script_out_point genesis_block get_block_by_number genesis_block_hash set_system_script_cell get_block_hash get_block system_script_cell get_tip_block_number get_cells_by_lock_hash get_tip_header get_transaction get_live_cell send_transaction local_node_info get_current_epoch get_epoch_by_number get_peers tx_pool_info rpc compute_transaction_hash get_blockchain_info get_peers_state calculate_dao_maximum_withdraw dry_run_transaction get_live_cells_by_lock_hash deindex_lock_hash get_lock_hash_index_states get_transactions_by_lock_hash index_lock_hash system_script_code_hash inspect).freeze
      sdk_api_names = CKB::API.instance_methods(false)

      assert_equal sdk_api_names.map(&:to_s).sort, contained_method_names.sort
    end
  end
end
