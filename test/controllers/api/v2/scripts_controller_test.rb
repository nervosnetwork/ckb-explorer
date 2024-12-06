require "test_helper"

module Api
  module V2
    class ScriptsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @code_hash = "0x00000000000000000000000000000000000000000000000000545950455f4944"
        @hash_type = "type"
        @block = create :block
        @type_script = create :type_script, code_hash: @code_hash, hash_type: @hash_type
        @cell_output1 = create :cell_output, :with_full_transaction, block: @block
        @cell_output2 = create :cell_output, :with_full_transaction, block: @block
        @cell_output3 = create :cell_output, :with_full_transaction, block: @block
        @contract = create :contract, type_hash: @code_hash, hash_type: @hash_type, deployed_cell_output_id: @cell_output1.id
      end

      test "should get ckb_transactions" do
        valid_get ckb_transactions_api_v2_scripts_url(code_hash: @code_hash, hash_type: @hash_type)
        assert_response :success
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
