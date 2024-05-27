require "test_helper"

module Api
  module V2
    class CkbTransactionsControllerTest < ActionDispatch::IntegrationTest
      test "should return 404 status code when tx_hash not found" do
        get details_api_v2_ckb_transaction_url("abc")
        assert_response :not_found
      end

      test "should return normal transaction details without udt info" do
        block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
        block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
        tx1 =  create(:ckb_transaction, block: block1)
        tx2 =  create(:ckb_transaction, block: block2)
        input_address1 = create(:address)
        input_address2 = create(:address)

        # create previous outputs
        create(:cell_output, ckb_transaction: tx1,
                             block: block1,
                             capacity: 50000 * 10**8,
                             occupied_capacity: 61 * 10**8,
                             tx_hash: tx1.tx_hash,
                             cell_index: 0,
                             address: input_address1)
        create(:cell_output, ckb_transaction: tx1,
                             block: block1,
                             capacity: 40000 * 10**8,
                             occupied_capacity: 61 * 10**8,
                             tx_hash: tx1.tx_hash,
                             cell_index: 1,
                             address: input_address2)
        # create inputs
        create(:cell_input, ckb_transaction: tx2,
                            block: block2,
                            previous_output: {
                              tx_hash: tx1.tx_hash,
                              index: 0,
                            })
        create(:cell_input, ckb_transaction: tx2,
                            block: block2,
                            previous_output: {
                              tx_hash: tx1.tx_hash,
                              index: 1,
                            })
        # create outputs
        create(:cell_output, ckb_transaction: tx2,
                             block: block2,
                             capacity: 30000 * 10**8,
                             tx_hash: tx2.tx_hash,
                             cell_index: 0,
                             address: input_address1)
        create(:cell_output, ckb_transaction: tx2,
                             block: block2,
                             capacity: 60000 * 10**8,
                             tx_hash: tx2.tx_hash,
                             cell_index: 1,
                             address: input_address2)

        get details_api_v2_ckb_transaction_url(tx2.tx_hash)

        data1 = json["data"].select { |item| item["address"] == input_address1.address_hash }
        transfers1 = data1[0]["transfers"]
        data2 = json["data"].select { |item| item["address"] == input_address2.address_hash }
        transfers2 = data2[0]["transfers"]

        assert_equal 2, json["data"].size
        assert_equal "-2000000000000.0", transfers1[0]["capacity"]
        assert_equal "2000000000000.0", transfers2[0]["capacity"]
      end

      test "should return udt transaction details with udt info" do
        udt_script = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                            args: "0x#{SecureRandom.hex(32)}")
        type_script = create(:type_script, args: udt_script.args, code_hash: Settings.sudt_cell_type_hash,
                                           hash_type: "data")
        udt = create(:udt, type_hash: CKB::Types::Script.new(**type_script.to_node).compute_hash,
                           args: udt_script.args, ckb_transactions_count: 2)

        block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
        block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
        tx1 =  create(:ckb_transaction, block: block1, contained_udt_ids: [udt.id])
        tx2 =  create(:ckb_transaction, block: block2, contained_udt_ids: [udt.id])
        input_address1 = create(:address)
        input_address2 = create(:address)

        # create udt previous outputs
        create(:cell_output, ckb_transaction: tx1,
                             block: block1,
                             udt_amount: 50000 * 10**8,
                             tx_hash: tx1.tx_hash,
                             cell_index: 0,
                             address: input_address1,
                             cell_type: "udt",
                             type_hash: udt_script.compute_hash)
        create(:cell_output, ckb_transaction: tx1,
                             block: block1,
                             udt_amount: 40000 * 10**8,
                             tx_hash: tx1.tx_hash,
                             cell_index: 1,
                             address: input_address2,
                             cell_type: "udt",
                             type_hash: udt_script.compute_hash)
        # create inputs
        create(:cell_input, ckb_transaction: tx2,
                            block: block2,
                            previous_output: {
                              tx_hash: tx1.tx_hash,
                              index: 0,
                            })
        create(:cell_input, ckb_transaction: tx2,
                            block: block2,
                            previous_output: {
                              tx_hash: tx1.tx_hash,
                              index: 1,
                            })
        # create outputs
        create(:cell_output, ckb_transaction: tx2,
                             block: block2,
                             udt_amount: 30000 * 10**8,
                             tx_hash: tx2.tx_hash,
                             cell_index: 0,
                             address: input_address1,
                             cell_type: "udt",
                             type_hash: udt_script.compute_hash)
        create(:cell_output, ckb_transaction: tx2,
                             block: block2,
                             udt_amount: 60000 * 10**8,
                             tx_hash: tx2.tx_hash,
                             cell_index: 1,
                             address: input_address2,
                             cell_type: "udt",
                             type_hash: udt_script.compute_hash)

        get details_api_v2_ckb_transaction_url(tx2.tx_hash)

        data1 = json["data"].select { |item| item["address"] == input_address1.address_hash }
        transfers1 = data1[0]["transfers"]
        data2 = json["data"].select { |item| item["address"] == input_address2.address_hash }
        transfers2 = data2[0]["transfers"]

        assert_equal 2, json["data"].size
        assert_equal "-2000000000000.000000", transfers1[0]["udt_info"]["amount"]
        assert_equal "2000000000000.000000", transfers2[0]["udt_info"]["amount"]
      end

      test "cellbase should can paginate either" do
        block = create(:block, number: 0)
        tx = create(:ckb_transaction, :with_cell_base, is_cellbase: true, block:)
        get display_outputs_api_v2_ckb_transaction_url(tx.tx_hash), params: { page: 1, page_size: 5 }
        assert_equal 5, json["data"].size
        assert_equal 15, json["meta"]["total"]
        assert_equal "5", json["meta"]["page_size"]
      end
    end
  end
end
