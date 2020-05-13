require "test_helper"

module CkbSync
  class ApiTest < ActiveSupport::TestCase
    test "should contain related methods" do
      contained_method_names = %w(get_live_cell send_transaction local_node_info get_current_epoch get_epoch_by_number get_peers tx_pool_info get_block_economic_state get_blockchain_info get_peers_state compute_transaction_hash compute_script_hash dry_run_transaction calculate_dao_maximum_withdraw deindex_lock_hash secp_cell_type_hash get_live_cells_by_lock_hash get_lock_hash_index_states get_transactions_by_lock_hash index_lock_hash get_capacity_by_lock_hash get_header_by_number get_cellbase_output_capacity_details set_ban get_banned_addresses estimate_fee_rate get_block_template submit_block inspect get_header rpc secp_group_out_point secp_code_out_point secp_data_out_point secp_cell_code_hash dao_out_point dao_code_hash dao_type_hash multi_sign_secp_cell_type_hash multi_sign_secp_group_out_point set_secp_group_dep set_dao_dep genesis_block get_block_by_number genesis_block_hash get_block_hash get_block get_tip_header get_tip_block_number get_cells_by_lock_hash get_transaction).freeze
      sdk_api_names = CKB::API.instance_methods(false)

      assert_equal contained_method_names.sort, sdk_api_names.map(&:to_s).sort
    end
  end
end
