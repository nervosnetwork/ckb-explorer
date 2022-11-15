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
      ::CKB::Types::Transaction.any_instance.stubs( :serialized_size_in_block).returns( 0 )
      create(:table_record_count, :block_counter)
      create(:table_record_count, :ckb_transactions_counter)
      CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
      GenerateStatisticsDataWorker.any_instance.stubs(:perform).returns(true)
      CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
    end

    test "#process_block should decrease address deposit when previous output is a dao cell" do
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)

        assert_difference -> { address.reload.dao_deposit }, -output.capacity do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "withdraw_from_dao")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      end
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
        withdraw_amount = 10**8 * 1000
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
        tx = fake_dao_interest_transaction(node_block)
        withdraw_amount = tx.cell_outputs.nervos_dao_withdrawing.first.capacity

        assert_difference -> { DaoContract.default_contract.reload.claimed_compensation }, "0x174876ebe8".hex - withdraw_amount do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "issue_interest")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      end
    end    

    test "#process_block should decrease dao contract depositors count when previous output is a dao cell and address interest change to zero" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)
        DaoContract.default_contract.update(total_deposit: 100000000000, depositors_count: 1)

        assert_difference -> { DaoContract.default_contract.reload.depositors_count }, -1 do
          node_data_processor.process_block(node_block)
        end

        take_away_all_deposit_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "take_away_all_deposit")
        assert_equal ["processed"], take_away_all_deposit_events.pluck(:status).uniq
      end
    end

    test "should update tx's tags when input have nervos_dao_withdrawing cells" do
      DaoContract.default_contract.update(total_deposit: 100000000000000)
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      deposit_block = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 5, dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100")
      deposit_tx = create(:ckb_transaction, block: deposit_block)
      deposit_block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 6, dao: "0x185369bb078607007224be7987882300517774e04400000000e3bad4847a0100")
      deposit_tx1 = create(:ckb_transaction, block: deposit_block1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      tx4 = create(:ckb_transaction, block: block2)
      tx5 = create(:ckb_transaction, block: block2)
      input_address1 = create(:address)
      input_address2 = create(:address)
      input_address3 = create(:address)
      input_address4 = create(:address)
      input_address5 = create(:address)
      create(:cell_output, ckb_transaction: deposit_tx, generated_by: deposit_tx, block: deposit_block, capacity: 50000 * 10**8, occupied_capacity: 61 * 10**8, tx_hash: deposit_tx.tx_hash, cell_index: 0, address: input_address1, cell_type: "nervos_dao_deposit", dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100")
      create(:cell_output, ckb_transaction: deposit_tx, generated_by: deposit_tx, block: deposit_block, capacity: 40000 * 10**8, occupied_capacity: 61 * 10**8, tx_hash: deposit_tx.tx_hash, cell_index: 1, address: input_address1, cell_type: "nervos_dao_deposit", dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100")
      create(:cell_input, ckb_transaction: tx1, block: block1, previous_output: { tx_hash: deposit_tx.tx_hash, index: 0 })
      create(:cell_input, ckb_transaction: tx2, block: block2, previous_output: { tx_hash: deposit_tx.tx_hash, index: 0 })
      create(:cell_input, ckb_transaction: tx2, block: block2, previous_output: { tx_hash: deposit_tx.tx_hash, index: 1 })
      create(:cell_output, ckb_transaction: tx1, generated_by: tx1, block: block1, capacity: 50000 * 10**8, tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, cell_type: "nervos_dao_withdrawing", dao: "0x28ef3c7ff3860700d88b1a61958923008ae424cd7200000000e3bad4847a0100", occupied_capacity: 6100000000)
      create(:cell_output, ckb_transaction: tx2, generated_by: tx2, block: block2, capacity: 60000 * 10**8, tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, cell_type: "nervos_dao_withdrawing", dao: "0x2cd631702e870700b3df08d7d889230036f787487e00000000e3bad4847a0100", occupied_capacity: 6100000000)
      create(:cell_output, ckb_transaction: tx3, generated_by: tx3, block: block2, capacity: 70000 * 10**8, tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3, occupied_capacity: 6100000000)

      create(:cell_output, ckb_transaction: deposit_tx1, generated_by: deposit_tx1, block: deposit_block1, capacity: 50000 * 10**8, occupied_capacity: 61 * 10**8, tx_hash: deposit_tx1.tx_hash, cell_index: 0, address: input_address4, cell_type: "nervos_dao_deposit", dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100")
      create(:cell_output, ckb_transaction: deposit_tx1, generated_by: deposit_tx1, block: deposit_block1, capacity: 40000 * 10**8, occupied_capacity: 61 * 10**8, tx_hash: deposit_tx1.tx_hash, cell_index: 1, address: input_address5, cell_type: "nervos_dao_deposit", dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100")
      create(:cell_input, ckb_transaction: tx4, block: block1, previous_output: { tx_hash: deposit_tx1.tx_hash, index: 0 })
      create(:cell_input, ckb_transaction: tx5, block: block2, previous_output: { tx_hash: deposit_tx1.tx_hash, index: 1 })
      create(:cell_output, ckb_transaction: tx4, generated_by: tx4, block: block1, capacity: 150000 * 10**8, tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4, cell_type: "nervos_dao_withdrawing", dao: "0x28ef3c7ff3860700d88b1a61958923008ae424cd7200000000e3bad4847a0100", occupied_capacity: 6100000000)
      create(:cell_output, ckb_transaction: tx5, generated_by: tx5, block: block2, capacity: 60000 * 10**8, tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5, cell_type: "nervos_dao_withdrawing", dao: "0x2cd631702e870700b3df08d7d889230036f787487e00000000e3bad4847a0100", occupied_capacity: 6100000000)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}", number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      outputs = [
        CKB::Types::Output.new(capacity: 50000 * 10**8, lock: lock1),
        CKB::Types::Output.new(capacity: 60000 * 10**8, lock: lock2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      outputs1 = [
        CKB::Types::Output.new(capacity: 50000 * 10**8, lock: lock1),
        CKB::Types::Output.new(capacity: 60000 * 10**8, lock: lock2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295), since: 3000)
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [block1.block_hash], inputs: inputs, outputs: outputs, outputs_data: %w[0x 0x 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [block1.block_hash], inputs: inputs1, outputs: outputs1, outputs_data: %w[0x 0x 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)

      tx = block.ckb_transactions.where(is_cellbase: false).first
      tx1 = block.ckb_transactions.where(is_cellbase: false).second

      assert_equal ["dao"], tx.tags
      assert_equal ["dao"], tx1.tags
      assert_equal 2, DaoContract.default_contract.ckb_transactions_count
    end        

    test "should increase address dao_deposit when block is invalid and previous output is a dao cell" do
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      DaoCompensationCalculator.any_instance.stubs(:call).returns(100800000000)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      target_address = nil
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)
        target_address = address
        node_data_processor.process_block(node_block)
      end

      local_block = Block.find_by(block_hash: "0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { target_address.reload.dao_deposit }, 10**8 * 1000 do
          node_data_processor.call
        end

        deposit_to_dao_events = local_block.dao_events.where(event_type: "withdraw_from_dao")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end    

    test "should increase dao contract total_deposit when block is invalid and previous output is a dao cell" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(100800000000)
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)

        node_data_processor.process_block(node_block)
      end

      local_block = Block.find_by(block_hash: "0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { DaoContract.default_contract.reload.total_deposit }, 10**8 * 1000 do
          node_data_processor.call
        end

        deposit_to_dao_events = local_block.dao_events.where(event_type: "withdraw_from_dao")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "should decrease dao contract withdraw_transactions_count when block is invalid and previous output is a dao cell" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)

        node_data_processor.process_block(node_block)
      end

      local_block = Block.find_by(block_hash: "0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { DaoContract.default_contract.reload.withdraw_transactions_count }, -1 do
          node_data_processor.call
        end

        deposit_to_dao_events = local_block.dao_events.where(event_type: "withdraw_from_dao")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "should decrease dao contract interest_granted when block is invalid and previous output is a dao cell" do
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_interest_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)

        node_data_processor.process_block(node_block)
      end

      local_block = Block.find_by(block_hash: "0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { DaoContract.default_contract.reload.claimed_compensation }, -1000 do
          node_data_processor.call
        end

        deposit_to_dao_events = local_block.dao_events.where(event_type: "issue_interest")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "should decrease address interest when block is invalid and previous output is a dao cell" do
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      target_address = nil
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_interest_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)
        target_address = address
        node_data_processor.process_block(node_block)
      end

      local_block = Block.find_by(block_hash: "0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { target_address.reload.interest }, -1000 do
          node_data_processor.call
        end

        deposit_to_dao_events = local_block.dao_events.where(event_type: "issue_interest")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "should increase dao contract depositors_count when block is invalid and previous output is a dao cell" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)
        node_data_processor.process_block(node_block)
      end

      local_block = Block.find_by(block_hash: "0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { DaoContract.default_contract.depositors_count }, 1 do
          node_data_processor.call
        end

        deposit_to_dao_events = local_block.dao_events.where(event_type: "take_away_all_deposit")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "#process_block should create dao_event which event_type is withdraw_from_dao when previous output is a dao cell" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_withdraw_transaction(node_block)
        DaoContract.default_contract.update(total_deposit: 100000000000)
        assert_difference -> { DaoEvent.where(event_type: "withdraw_from_dao").count }, 1 do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "withdraw_from_dao")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
        assert_equal %w(block_id ckb_transaction_id address_id contract_id event_type value status block_timestamp), deposit_to_dao_events.first.attribute_names.reject { |attribute| attribute.in?(%w(created_at updated_at id)) }
      end
    end

    test "#process_block should create dao_event which event_type is issue interest when previous output is a dao cell" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(100800000000)
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_interest_transaction(node_block)

        assert_difference -> { DaoEvent.where(event_type: "issue_interest").count }, 1 do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "issue_interest")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "#process_block should create dao_event which event_type is take away all deposit when previous output is a dao cell and address interest change to zero" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)

        assert_difference -> { DaoEvent.where(event_type: "take_away_all_deposit").count }, 1 do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "take_away_all_deposit")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      end
    end




    test "#process_block should keep address deposit 0 when only have dao withdrawal event" do
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      DaoCompensationCalculator.any_instance.stubs(:call).returns(1000)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address

        assert_equal 0, address.reload.dao_deposit
      end
    end

    test "#process_block should increase address interest when previous output is a withdrawing cell" do
      DaoCompensationCalculator.any_instance.stubs(:call).returns(100800000000)
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_interest_transaction(node_block)
        nervos_dao_withdrawing_cell = tx.cell_outputs.nervos_dao_withdrawing.first
        nervos_dao_deposit_cell = tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)

        assert_difference -> { address.reload.interest }, 100800000000 do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "issue_interest")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "should do nothing on dao contract when block is invalid but there is no dao cell" do
      dao_contract = create(:dao_contract)
      init_total_deposit = 10**8 * 10000
      init_depositors_count = 3
      init_interest_granted = 10**8 * 100
      init_deposit_transactions_count = 2
      init_withdraw_transactions_count = 1
      init_total_depositors_count = 2
      dao_contract.update(total_deposit: init_total_deposit, depositors_count: init_depositors_count, claimed_compensation: init_interest_granted, deposit_transactions_count: init_deposit_transactions_count, withdraw_transactions_count: init_withdraw_transactions_count, total_depositors_count: init_total_depositors_count)
      prepare_node_data(HAS_UNCLES_BLOCK_NUMBER)
      local_block = Block.find_by(number: HAS_UNCLES_BLOCK_NUMBER)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}", record: :new_episodes) do
        node_data_processor.call
        dao_contract.reload
        assert_equal init_total_deposit, dao_contract.total_deposit
        assert_equal init_depositors_count, dao_contract.depositors_count
        assert_equal init_interest_granted, dao_contract.claimed_compensation
        assert_equal init_deposit_transactions_count, dao_contract.deposit_transactions_count
        assert_equal init_withdraw_transactions_count, dao_contract.withdraw_transactions_count
        assert_equal init_total_depositors_count, dao_contract.total_depositors_count
      end
    end

    test "should do nothing on address when block is invalid but there is no dao cell" do
      prepare_node_data(HAS_UNCLES_BLOCK_NUMBER)
      local_block = Block.find_by(number: HAS_UNCLES_BLOCK_NUMBER)
      addresses = local_block.contained_addresses
      dao_deposits = addresses.map(&:dao_deposit)
      dao_subsidies = addresses.map(&:interest)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}", record: :new_episodes) do
        local_block = node_data_processor.call

        assert_equal dao_deposits, local_block.contained_addresses.map(&:dao_deposit)
        assert_equal dao_subsidies, local_block.contained_addresses.map(&:interest)
      end
    end

    test "should revert address dao deposit when block is invalid and there is dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      target_address = nil
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_deposit_transaction(node_block)
        output = tx.outputs.first
        address = Address.find_or_create_address(output.lock, node_block.header.timestamp)
        target_address = address
        assert_difference -> { address.reload.dao_deposit }, 10**8 * 1000 do
          node_data_processor.process_block(node_block)
        end
      end

      local_block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        local_block = node_data_processor.call
        assert target_address.in?(local_block.contained_addresses)
        assert_equal [0], local_block.contained_addresses.map(&:dao_deposit).uniq

        deposit_to_dao_events = local_block.dao_events.where(event_type: "deposit_to_dao")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "should revert dao contract total deposit when block is invalid and there is dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)
        node_data_processor.process_block(node_block)
      end
      dao_contract = DaoContract.default_contract
      local_block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { dao_contract.reload.total_deposit }, -(10**8 * 1000) do
          node_data_processor.call
        end

        deposit_to_dao_events = local_block.dao_events.where(event_type: "deposit_to_dao")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "should revert dao contract deposit transactions count when block is invalid and there is dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)
        node_data_processor.process_block(node_block)
      end
      dao_contract = DaoContract.default_contract
      local_block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { dao_contract.reload.deposit_transactions_count }, -1 do
          node_data_processor.call
        end

        deposit_to_dao_events = local_block.dao_events.where(event_type: "deposit_to_dao")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "should revert dao contract depositors count when block is invalid and there is dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)
        node_data_processor.process_block(node_block)
      end
      dao_contract = DaoContract.default_contract
      local_block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { dao_contract.reload.depositors_count }, -1 do
          node_data_processor.call
        end

        deposit_to_dao_events = local_block.dao_events.where(event_type: "new_dao_depositor")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end


    test "#process_block should create dao_event which event_type is new_dao_depositor when output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoEvent.where(event_type: "new_dao_depositor").count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should update address deposits when dao_event is deposit_to_dao and output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_deposit_transaction(node_block)
        output = tx.outputs.first
        address = Address.find_or_create_address(output.lock, node_block.header.timestamp)

        assert_difference -> { address.reload.dao_deposit }, 10**8 * 1000 do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "deposit_to_dao")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "#process_block should update dao contract total deposits when dao_event is deposit_to_dao and output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoContract.default_contract.total_deposit }, 10**8 * 1000 do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "deposit_to_dao")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "#process_block should update dao contract deposit transactions count when dao_event is deposit_to_dao and output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoContract.default_contract.deposit_transactions_count }, 1 do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "deposit_to_dao")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "#process_block should update dao contract depositors count when dao_event is new_dao_depositor and output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoContract.default_contract.depositors_count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end

      deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "new_dao_depositor")
      assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
      assert_not_empty DaoEvent.where(event_type: "new_dao_depositor")
    end

    test "#process_block should update dao contract total depositors count when dao_event is new_dao_depositor and output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoContract.default_contract.total_depositors_count }, 1 do
          node_data_processor.process_block(node_block)
        end

        deposit_to_dao_events = Block.find_by(number: node_block.header.number).dao_events.where(event_type: "new_dao_depositor")
        assert_equal ["processed"], deposit_to_dao_events.pluck(:status).uniq
        assert_equal %w(block_id ckb_transaction_id address_id contract_id event_type value status block_timestamp), deposit_to_dao_events.first.attribute_names.reject { |attribute| attribute.in?(%w(created_at updated_at id)) }
      end
    end

    test "#process_block should not update dao contract total depositors count when depositors is already has been recorded" do
      DaoContract.default_contract.update(total_deposit: 100000000000000, depositors_count: 1, total_depositors_count: 1)
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      lock = node_block.transactions.last.outputs.first.lock
      lock_script = create(:lock_script, code_hash: lock.code_hash, hash_type: lock.hash_type, args: lock.args)
      address = Address.find_or_create_address(lock, node_block.header.timestamp, lock_script.id)
      address.update(dao_deposit: 100000 * 10**8)
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, capacity: 10**8 * 1000, address: address)
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block, capacity: 10**8 * 1000, address: address)
      tx1 = node_block.transactions.first
      output1 = tx1.outputs.first
      output1.type = CKB::Types::Script.new(args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type", code_hash: ENV["DAO_TYPE_HASH"])
      output1.capacity = 10**8 * 1000
      tx1.outputs << output1
      tx1.outputs_data << CKB::Utils.bin_to_hex("\x00" * 8)

      assert_no_changes -> { DaoContract.default_contract.total_depositors_count } do
        node_data_processor.process_block(node_block)
      end
    end

    test "#process_block should not update dao contract depositors count when depositors is already has been recorded" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      address = create(:address)
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, capacity: 10**8 * 1000, address: address)
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block, capacity: 10**8 * 1000, address: address)
      tx1 = node_block.transactions.first
      output1 = tx1.outputs.first
      output1.type = CKB::Types::Script.new(args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type", code_hash: ENV["DAO_TYPE_HASH"])
      output1.capacity = 10**8 * 1000
      tx1.outputs << output1
      tx1.outputs_data << CKB::Utils.bin_to_hex("\x00" * 8)

      assert_difference -> { DaoContract.default_contract.depositors_count }, 1 do
        node_data_processor.process_block(node_block)
      end
    end

    test "should update tx's tags when output have nervos_dao_withdrawing cells" do
      DaoContract.default_contract.update! total_deposit: 10**20
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      tx4 = create(:ckb_transaction, block: block2)
      tx5 = create(:ckb_transaction, block: block2)
      input_address1 = create(:address)
      input_address2 = create(:address)
      input_address3 = create(:address)
      input_address4 = create(:address)
      input_address5 = create(:address)
      create(:cell_output, ckb_transaction: tx1, generated_by: tx1, block: block1, capacity: 50000 * 10**8, tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, cell_type: "nervos_dao_deposit")
      create(:cell_output, ckb_transaction: tx2, generated_by: tx2, block: block2, capacity: 60000 * 10**8, tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, cell_type: "nervos_dao_deposit")
      create(:cell_output, ckb_transaction: tx3, generated_by: tx3, block: block2, capacity: 70000 * 10**8, tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3)
      create(:cell_output, ckb_transaction: tx4, generated_by: tx4, block: block2, capacity: 70000 * 10**8, tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4, cell_type: "nervos_dao_deposit")
      create(:cell_output, ckb_transaction: tx5, generated_by: tx5, block: block2, capacity: 70000 * 10**8, tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5, cell_type: "nervos_dao_deposit")
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}", number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      dao_type = CKB::Types::Script.new(code_hash: ENV["DAO_TYPE_HASH"], hash_type: "type", args: "0x")
      outputs = [
        CKB::Types::Output.new(capacity: 50000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 60000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      outputs1 = [
        CKB::Types::Output.new(capacity: 50000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 60000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295), since: 3000)
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      deposit_block_number = CKB::Utils.bin_to_hex([block1.number].pack("Q<"))
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [block1.block_hash], inputs: inputs, outputs: outputs, outputs_data: %W[#{deposit_block_number} #{deposit_block_number} 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [block1.block_hash], inputs: inputs1, outputs: outputs1, outputs_data: %W[#{deposit_block_number} #{deposit_block_number} 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)

      block = node_data_processor.process_block(node_block)

      tx = block.ckb_transactions.where(is_cellbase: false).first
      tx1 = block.ckb_transactions.where(is_cellbase: false).second
      assert_equal ["dao"], tx.tags
      assert_equal ["dao"], tx1.tags
      assert_equal 2, DaoContract.default_contract.ckb_transactions_count
    end

    test "should update tx's tags when output have udt cells and nervos_dao_withdrawing cell" do
      DaoContract.default_contract.update! total_deposit: 10**20
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      input_address1 = create(:address)
      input_address2 = create(:address)
      input_address3 = create(:address)
      create(:cell_output, ckb_transaction: tx1, generated_by: tx1, block: block1, capacity: 50000 * 10**8, tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, cell_type: "nervos_dao_deposit")
      create(:cell_output, ckb_transaction: tx2, generated_by: tx2, block: block2, capacity: 60000 * 10**8, tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, cell_type: "nervos_dao_deposit")
      create(:cell_output, ckb_transaction: tx3, generated_by: tx3, block: block2, capacity: 70000 * 10**8, tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}", number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      lock1 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      udt_script = CKB::Types::Script.new(code_hash: ENV["SUDT_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script.args, address_hash: "0x#{SecureRandom.hex(32)}")
      dao_type = CKB::Types::Script.new(code_hash: ENV["DAO_TYPE_HASH"], hash_type: "type", args: "0x")
      outputs = [
        CKB::Types::Output.new(capacity: 50000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 60000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3, type: udt_script)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: ENV["SECP_CELL_TYPE_HASH"], hash_type: "type", args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295), since: 3000)
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      deposit_block_number = CKB::Utils.bin_to_hex([block1.number].pack("Q<"))
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [block1.block_hash], inputs: inputs, outputs: outputs, outputs_data: %W[#{deposit_block_number} #{deposit_block_number} #{CKB::Utils.generate_sudt_amount(1000)}], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)

      tx = block.ckb_transactions.where(is_cellbase: false).first
      assert_equal %w[dao udt], tx.tags
      assert_equal 1, DaoContract.default_contract.ckb_transactions_count
    end    
private
    def node_data_processor
      CkbSync::NewNodeDataProcessor.new
    end

    def fake_dao_withdraw_transaction(node_block)
      block = create(:block, :with_block_hash)
      lock = create(:lock_script)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      cell_output1 = create(:cell_output, 
                          ckb_transaction: ckb_transaction1, 
                          cell_index: 1, 
                          tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", 
                          generated_by: ckb_transaction2, 
                          block: block, 
                          cell_type: "nervos_dao_deposit", 
                          capacity: 10**8 * 1000, 
                          data: CKB::Utils.bin_to_hex("\x00" * 8), 
                          lock_script_id: lock.id)
      cell_output2 = create(:cell_output, 
                          ckb_transaction: ckb_transaction2, 
                          cell_index: 2, 
                          tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", 
                          generated_by: ckb_transaction1, 
                          block: block, capacity: 10**8 * 1000, 
                          lock_script_id: lock.id)
      cell_output1.address.update(balance: 10 ** 8 * 1000)
      cell_output2.address.update(balance: 10 ** 8 * 1000)
      tx = node_block.transactions.last
      output = tx.outputs.first
      output.type = CKB::Types::Script.new(args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type", code_hash: ENV["DAO_TYPE_HASH"])
      tx.outputs_data[0] = CKB::Utils.bin_to_hex("\x02" * 8)
      output.capacity = 10**8 * 1000
      tx.header_deps = ["0x0b3e980e4e5e59b7d478287e21cd89ffdc3ff5916ee26cf2aa87910c6a504d61"]
      tx.witnesses = ['0x550000001000000055000000550000004100000055a49d9dde8450178687a2eddf21e28d8e1bf012a9a741e253b380d99fd4131f543131ccfa6ee6f6a671836430041ff0e995b814c01c2206171c05020358551001']
      ckb_transaction1
    end

    def fake_dao_interest_transaction(node_block)
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
