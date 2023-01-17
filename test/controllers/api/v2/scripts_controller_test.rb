require "test_helper"

module Api
  module V2
    class ScriptsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @code_hash = '0x00000000000000000000000000000000000000000000000000545950455f4944'
        @hash_type = 'type'
        @type_script = create(:type_script, code_hash: @code_hash, hash_type: @hash_type )
      end

      test "should get ckb_transactions" do
        valid_get ckb_transactions_api_v2_scripts_url(code_hash: @code_hash, hash_type: @hash_type)
        assert_response :success
      end

      test "should get deployed_cells" do
        valid_get deployed_cells_api_v2_scripts_url(code_hash: @code_hash, hash_type: @hash_type)
        assert_response :success
      end

    end
  end
end
