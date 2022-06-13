require "test_helper"

module CkbSync
  class DaoEventsTest < ActiveSupport::TestCase
    setup do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x07d0",
          number: "0x0",
          start_number: "0x0"
        )
      )
      create(:table_record_count, :block_counter)
      create(:table_record_count, :ckb_transactions_counter)
      CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
      GenerateStatisticsDataWorker.any_instance.stubs(:perform).returns(true)
      CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
    end

    test "#process_block should create dao_event which event_type is deposit_to_dao when output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoEvent.where(event_type: "deposit_to_dao").count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end    

    test "#process_block should increase dao contract withdraw transactions count when previous output is a dao cell" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_withdraw_transaction(node_block)

        assert_difference -> { DaoContract.default_contract.withdraw_transactions_count }, 1 do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "withdraw_from_dao")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
        assert_equal %w(block_id ckb_transaction_id address_id contract_id event_type value status block_timestamp), deposit_to_dao_events.first.attribute_names.reject { |attribute| attribute.in?(%w(created_at updated_at id)) }
      end
    end

    test "#process_block should decrease dao contract total deposit when previous output is a withdrawing cell" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        withdraw_amount = tx.cell_outputs.nervos_dao_withdrawing.first.capacity
        DaoContract.default_contract.update(total_deposit: withdraw_amount)

        assert_difference -> { DaoContract.default_contract.total_deposit }, -withdraw_amount do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "withdraw_from_dao")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "#process_block should increase dao contract interest granted when previous output is a withdrawing cell" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        withdraw_amount = tx.cell_outputs.nervos_dao_withdrawing.first.capacity

        assert_difference -> { DaoContract.default_contract.reload.claimed_compensation }, "0x174876ebe8".hex - withdraw_amount do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "issue_interest")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      end
    end    
private
    def node_data_processor
      CkbSync::NewNodeDataProcessor.new
    end

    def fake_dao_withdraw_transaction(node_block)
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      lock = create(:lock_script)
      cell_output1 = create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block, cell_type: "nervos_dao_withdrawing", capacity: 10**8 * 1000, data: CKB::Utils.bin_to_hex("\x02" * 8), lock_script_id: lock.id)
      cell_output2 = create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 1, tx_hash: "0x398315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e2", generated_by: ckb_transaction1, block: block, consumed_by: ckb_transaction2, cell_type: "nervos_dao_deposit", capacity: 10**8 * 1000, data: CKB::Utils.bin_to_hex("\x00" * 8), lock_script_id: lock.id)
      cell_output3 = create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block, lock_script_id: lock.id)
      cell_output1.address.update(balance: 10 ** 8 * 1000)
      cell_output2.address.update(balance: 10 ** 8 * 1000)
      cell_output3.address.update(balance: 10 ** 8 * 1000)
      create(:cell_input, block: ckb_transaction2.block, ckb_transaction: ckb_transaction2, previous_output: { "tx_hash": "0x398315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e2", "index": "1" })
      create(:cell_input, block: ckb_transaction2.block, ckb_transaction: ckb_transaction2, previous_output: { "tx_hash": "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", "index": "2" })
      create(:cell_input, block: ckb_transaction1.block, ckb_transaction: ckb_transaction1, previous_output: { "tx_hash": "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", "index": "1" })
      create(:cell_input, block: ckb_transaction1.block, ckb_transaction: ckb_transaction1, previous_output: { "tx_hash": "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", "index": "1" })

      tx = node_block.transactions.last
      tx.header_deps = ["0x0b3e980e4e5e59b7d478287e21cd89ffdc3ff5916ee26cf2aa87910c6a504d61"]
      tx.witnesses = %w(0x8ae8061ec879d66c0f3996ab60d7c2a21094b8739817beddaea1e28d3620a70a21497a692581ca352631a67f3f6659a7c47d9a0c6c2def79d3e39440918a66fef 0x4e52933358ae2f26863b8c1c71bf20f17489328820f8f2cd84a070069f10ceef784bc3693c3c51b93475a7b5dbf652ba6532d0580ecc1faf909f9fd53c5f6405000000000000000000)

      ckb_transaction1
    end

    def fake_dao_deposit_transaction(node_block)
      block = create(:block, :with_block_hash)
      lock = create(:lock_script)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      cell_output1 = create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, capacity: 10**8 * 1000, lock_script_id: lock.id)
      cell_output2 = create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block, capacity: 10**8 * 1000, lock_script_id: lock.id)
      cell_output1.address.update(balance: 10 ** 8 * 1000)
      cell_output2.address.update(balance: 10 ** 8 * 1000)
      tx = node_block.transactions.first
      output = tx.outputs.first
      output.type = CKB::Types::Script.new(args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type", code_hash: ENV["DAO_TYPE_HASH"])
      tx.outputs_data[0] = CKB::Utils.bin_to_hex("\x00" * 8)
      output.capacity = 10**8 * 1000

      tx
    end
  end
end
