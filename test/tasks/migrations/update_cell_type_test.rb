require "test_helper"
require "rake"

class UpdateCotaCellTypeTest < ActiveSupport::TestCase
  setup do
    CkbSync::Api.any_instance.stubs(:cota_registry_code_hash).returns(Settings.testnet_cota_registry_code_hash)
    CkbSync::Api.any_instance.stubs(:cota_regular_code_hash).returns(Settings.testnet_cota_regular_code_hash)
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb"))
    Server::Application.load_tasks if Rake::Task.tasks.empty?
  end

  test "update registry cota cell type" do
    tx_hash = "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3"
    block = create(:block, :with_block_hash)
    ckb_transaction = create(:ckb_transaction, block: block, tx_hash: tx_hash)
    input_address = create(:address)
    lock_script = create(:lock_script)
    type_script = create(:type_script, code_hash: Settings.testnet_cota_registry_code_hash)
    cell_output = create(:cell_output, ckb_transaction: ckb_transaction, block: block,
                                       tx_hash: ckb_transaction.tx_hash, address: input_address,
                                       lock_script: lock_script, type_script: type_script,
                                       cell_index: 1)
    cell_input = create(:cell_input,
                        block: ckb_transaction.block,
                        ckb_transaction: ckb_transaction,
                        previous_output: {
                          "tx_hash": tx_hash,
                          "index": "1"
                        })

    Rake::Task["migration:update_cell_type"].execute

    assert_equal "cota_registry", cell_output.reload.cell_type
    assert_equal "cota_registry", cell_input.reload.cell_type
  end

  test "update regular cota cell type" do
    tx_hash = "0x398315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e2"
    block = create(:block, :with_block_hash)
    ckb_transaction = create(:ckb_transaction, block: block, tx_hash: tx_hash)
    input_address = create(:address)
    lock_script = create(:lock_script)
    type_script = create(:type_script, code_hash: Settings.testnet_cota_regular_code_hash)
    cell_output = create(:cell_output, ckb_transaction: ckb_transaction, block: block,
                                       tx_hash: ckb_transaction.tx_hash, address: input_address,
                                       lock_script: lock_script, type_script: type_script,
                                       cell_index: 1)
    cell_input = create(:cell_input,
                        block: ckb_transaction.block,
                        ckb_transaction: ckb_transaction,
                        previous_output: {
                          "tx_hash": tx_hash,
                          "index": "1"
                        })
    Rake::Task["migration:update_cell_type"].execute

    assert_equal "cota_regular", cell_output.reload.cell_type
    assert_equal "cota_regular", cell_input.reload.cell_type
  end
end
