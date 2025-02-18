require "test_helper"

module Api
  module V2
    class ScriptsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @code_hash = "0x00000000000000000000000000000000000000000000000000545950455f4944"
        @hash_type = "type"
        @block = create :block
        deployed_tx = create(:ckb_transaction, block: @block)
        deployed_cell_output = create(:cell_output, ckb_transaction: deployed_tx, block: @block)
        @contract_cell_tx = create(:ckb_transaction, block: @block)
        contract_cell_output = create(:cell_output, ckb_transaction: @contract_cell_tx, block: @block)
        unused_ckb_transaction = create(:ckb_transaction, block: @block)
        cell_output = create :cell_output, ckb_transaction: unused_ckb_transaction, block: @block
        create :cell_dependency, ckb_transaction_id: unused_ckb_transaction.id, contract_cell_id: cell_output.id, is_used: false
        create :cell_deps_out_point, contract_cell_id: cell_output.id, deployed_cell_output_id: deployed_cell_output.id
        create :contract, type_hash: @code_hash, hash_type: @hash_type, deployed_cell_output_id: deployed_cell_output.id, is_type_script: true
        create :cell_dependency, ckb_transaction_id: @contract_cell_tx.id, contract_cell_id: contract_cell_output.id
        create :cell_deps_out_point, contract_cell_id: contract_cell_output.id, deployed_cell_output_id: deployed_cell_output.id
      end

      test "should return all ckb_transactions in normal mode" do
        valid_get ckb_transactions_api_v2_scripts_url(code_hash: @code_hash, hash_type: @hash_type)
        json = JSON.parse response.body
        assert_equal 2, json["data"]["ckb_transactions"].count
      end

      test "should return used ckb_transaction in restrict mode" do
        valid_get ckb_transactions_api_v2_scripts_url(code_hash: @code_hash, hash_type: @hash_type, restrict: "true")
        json = JSON.parse response.body
        assert_equal 1, json["data"]["ckb_transactions"].count
        assert_equal @contract_cell_tx.id, json["data"]["ckb_transactions"][0]["id"]
      end

      test "should get deployed_cells" do
        valid_get deployed_cells_api_v2_scripts_url(code_hash: @code_hash, hash_type: @hash_type)
        assert_response :success
      end

      test "should get referring_cells" do
        valid_get referring_cells_api_v2_scripts_url(code_hash: @code_hash, hash_type: @hash_type)
        assert_response :success
      end
    end
  end
end
