require "test_helper"
require "rake"

class UpdateOmigaInscriptionUdtTest < ActiveSupport::TestCase
  setup do
    Server::Application.load_tasks if Rake::Task.tasks.empty?
  end

  test "update omiga inscription" do
    CkbSync::Api.any_instance.stubs(:xudt_code_hash).returns("0x25c29dc317811a6f6f3985a7a9ebc4838bd388d19d0feeecf0bcd60f6c0975bb")
    CkbSync::Api.any_instance.stubs(:omiga_inscription_info_code_hash).returns("0x50fdea2d0030a8d0b3d69f883b471cab2a29cae6f01923f19cecac0f27fdaaa6")

    block1 = create(:block, :with_block_hash, number: 0)
    tx1 = create(:ckb_transaction, block: block1,
                                   tx_hash: "0x3e89753ebca825e1504498eb18b56576d5b7eff59fe033346a10ab9e8ca359a4")
    input_address1 = create(:address)
    address1_lock = create(:lock_script, address_id: input_address1.id)
    info_ts = create(:type_script,
                     args: "0xcd89d8f36593a9a82501c024c5cdc4877ca11c5b3d5831b3e78334aecb978f0d",
                     code_hash: "0x50fdea2d0030a8d0b3d69f883b471cab2a29cae6f01923f19cecac0f27fdaaa6",
                     hash_type: "type")
    info_output = create(:cell_output, ckb_transaction: tx1,
                                       block: block1, capacity: 50000000 * 10**8,
                                       tx_hash: tx1.tx_hash,
                                       cell_index: 1,
                                       address: input_address1,
                                       cell_type: "normal",
                                       lock_script_id: address1_lock.id,
                                       type_script_id: info_ts.id)
    info_output.data = "0x0814434b42204669737420496e736372697074696f6e04434b42495fa66c8d5f43914f85d3083e0529931883a5b0a14282f891201069f1b50679080040075af0750700000000000000000000e8764817000000000000000000000000"

    input_address2 = create(:address)
    address2_lock = create(:lock_script, address_id: input_address2.id)

    xudt_ts = create(:type_script,
                     args: "0x9709d30fc21348ae1d28a197310a80aec3b8cdb5c93814d5e240f9fba85b76af",
                     code_hash: "0x25c29dc317811a6f6f3985a7a9ebc4838bd388d19d0feeecf0bcd60f6c0975bb",
                     hash_type: "type",
                     script_hash: "0x5fa66c8d5f43914f85d3083e0529931883a5b0a14282f891201069f1b5067908")
    block2 = create(:block, :with_block_hash, number: 1)
    tx2 = create(:ckb_transaction, block: block2,
                                   tx_hash: "0xd5d38a2096c10e5d0d55def7f2b3fe58779aad831fbc9dcd594446b1f0837430")
    xudt_output = create(:cell_output, ckb_transaction: tx2,
                                       block: block2, capacity: 50000000 * 10**8,
                                       tx_hash: tx2.tx_hash,
                                       type_hash: xudt_ts.script_hash,
                                       cell_index: 1,
                                       address: input_address2,
                                       cell_type: "normal",
                                       lock_script_id: address2_lock.id,
                                       type_script_id: xudt_ts.id)
    input_address3 = create(:address)
    address3_lock = create(:lock_script, address_id: input_address3.id)
    tx3 = create(:ckb_transaction, block: block2,
                                   tx_hash: "0xd5d38a2096c10e5d0d55def7f2b3fe58779aad831fbc9dcd594446b1f0837431")
    xudt3_output = create(:cell_output, ckb_transaction: tx3,
                                        block: block2, capacity: 50000000 * 10**8,
                                        tx_hash: tx3.tx_hash,
                                        type_hash: xudt_ts.script_hash,
                                        cell_index: 1,
                                        address: input_address3,
                                        cell_type: "normal",
                                        lock_script_id: address3_lock.id,
                                        type_script_id: xudt_ts.id)

    xudt3_output.data = "0x00e87648170000000000000000000000"
    Rake::Task["migration:update_omiga_inscription_udt"].execute
    assert_equal 1, OmigaInscriptionInfo.count
    assert_equal 1, Udt.count
    assert_equal 2, UdtTransaction.count
    assert_equal 2, AddressUdtTransaction.count
    assert_equal 2, UdtAccount.count
    assert_equal 100000000000, UdtAccount.first.amount
    assert_equal 200000000000, Udt.first.total_amount
  end
end
