require "test_helper"

class SsriContractWorkerTest < ActiveJob::TestCase
  setup do
    @tx = create(:ckb_transaction)
    deployed_cell_output = create(:cell_output, ckb_transaction: @tx, capacity: 1000)
    @contract = create(:contract, deployed_cell_output_id: deployed_cell_output.id)
    @type_script = create(:type_script, code_hash: @contract.type_hash, hash_type: "type", args: "0x02c93173368ec56f72ec023f63148461b80e7698eddd62cbd9dbe31a13f2b330")
    @cell_output = create(:cell_output, ckb_transaction: @tx, tx_hash: @tx.tx_hash, cell_index: @tx.tx_index, type_script: @type_script, capacity: 1000)
    create(:cell_datum, cell_output: @cell_output, data: "0x00d0d1f1378423000000000000000000")
  end

  test "should create ssri contract" do
    SsriIndexer.any_instance.stubs(:fetch_methods).returns("0x0d0000006f2a4642323106f858f02409de9de7b1b43d1128f8726c19c78a67cec2fcc54f35fa711c8c918aad2f87f08056af234da306f89e40893737235c6c5c6ee04b089adf445d336222e12e04fafee9f986ea03cd9ce840759d42849def40c0e9a52543f92b1ceda6fa2b")
    SsriIndexer.any_instance.stubs(:fetch_all_udt_fields).returns({
                                                                    name: "Pausable UDT without external data",
                                                                    symbol: "PUDT",
                                                                    decimal: 6,
                                                                    icon: "http://example.com/icon.png",
                                                                  })

    SsriContractWorker.new.perform([@contract.id])
    assert_equal "Pausable UDT without external data", Udt.first.full_name
    assert_equal @type_script.script_hash, Udt.first.type_hash
    assert_equal 9997000000000000, UdtAccount.first.amount
    assert_equal 1, UdtTransaction.count
    assert_equal 9997000000000000, @cell_output.reload.udt_amount
  end
end
