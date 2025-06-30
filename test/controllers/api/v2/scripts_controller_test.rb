require "test_helper"

module Api
  module V2
    class ScriptsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @code_hash = "0x00000000000000000000000000000000000000000000000000545950455f4944"
        @hash_type = "type"
        @block = create :block
        deployed_tx = create(:ckb_transaction, block: @block)
        deployed_cell_output = create(:cell_output, ckb_transaction: deployed_tx, block: @block, tx_hash: deployed_tx.tx_hash, cell_index: 0)
        @contract_cell_tx = create(:ckb_transaction, block: @block)
        contract_cell_output = create(:cell_output, ckb_transaction: @contract_cell_tx, block: @block)
        unused_ckb_transaction = create(:ckb_transaction, block: @block)
        cell_output = create :cell_output, ckb_transaction: unused_ckb_transaction, block: @block
        create :cell_dependency, ckb_transaction_id: unused_ckb_transaction.id, contract_cell_id: cell_output.id, is_used: false
        create :cell_deps_out_point, contract_cell_id: cell_output.id, deployed_cell_output_id: deployed_cell_output.id
        @contract = create :contract, type_hash: @code_hash, hash_type: @hash_type, deployed_cell_output_id: deployed_cell_output.id, contract_cell_id: deployed_cell_output.id, is_type_script: true
        create :cell_dependency, ckb_transaction_id: @contract_cell_tx.id, contract_cell_id: contract_cell_output.id
        create :cell_deps_out_point, contract_cell_id: contract_cell_output.id, deployed_cell_output_id: deployed_cell_output.id
        create(:contract,
               hash_type: "data",
               name: "Zero Lock",
               verified: true,
               deprecated: false,
               type_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
               data_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
               deployed_cell_output_id: nil,
               deployed_block_timestamp: DailyStatistic::GENESIS_TIMESTAMP,
               is_type_script: false,
               is_lock_script: true,
               is_primary: true,
               is_zero_lock: true)
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

      test "should returns contract list" do
        valid_get api_v2_scripts_url
        json = JSON.parse response.body
        assert_response :success
        assert @contract.name, json["data"].first["name"]
      end

      test "should returns first page " do
        outputs = create_list(:cell_output, 10, :with_full_transaction)
        outputs.each do |output|
          create(:contract, deployed_cell_output_id: output.id)
        end

        valid_get api_v2_scripts_url(page: 1, page_size: 10)
        json = JSON.parse response.body
        assert_response :success
        assert 10, json["data"].length
      end

      test "should return general info" do
        valid_get general_info_api_v2_scripts_url(code_hash: @code_hash, hash_type: @hash_type)
        json = JSON.parse response.body
        assert_equal [
          {
            "name" => @contract.name,
            "type_hash" => @code_hash,
            "data_hash" => nil,
            "hash_type" => "type",
            "is_lock_script" => nil,
            "is_type_script" => true,
            "rfc" => nil,
            "website" => nil,
            "description" => "SECP256K1/multisig (Source Code) is a script which allows a group of users to sign a single transaction.",
            "deprecated" => false,
            "verified" => true,
            "source_url" => nil,
            "capacity_of_deployed_cells" => @contract.deployed_cell_output.capacity.to_s,
            "capacity_of_referring_cells" => @contract.total_referring_cells_capacity.to_s,
            "count_of_transactions" => @contract.ckb_transactions_count,
            "count_of_referring_cells" => 0,
            "script_out_point" => "#{@contract.contract_cell.tx_hash}-#{@contract.contract_cell.cell_index}",
            "dep_type" => @contract.dep_type,
            "is_zero_lock" => false,
            "is_deployed_cell_dead" => false,
          },
        ],
                     json["data"]
      end

      test "should filter by notes" do
        outputs = create_list(:cell_output, 10, :with_full_transaction)
        outputs.each do |output|
          create(:contract, deployed_cell_output_id: output.id, rfc: "https://test.com/rfc")
        end
        valid_get api_v2_scripts_url(notes: ["ownerless_cell", "rfc"])
        json = JSON.parse response.body
        assert_equal 10, json["data"].count
        assert_equal "Zero Lock", json["data"].first["name"]
      end
    end
  end
end
