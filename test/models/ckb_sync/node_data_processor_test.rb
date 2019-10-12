require "test_helper"

module CkbSync
  class NodeDataProcessorTest < ActiveSupport::TestCase
    setup do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x07d0",
          number: "0x0",
          start_number: "0x0"
        )
      )
    end

    test "#process_block should create one block" do
      assert_difference -> { Block.count }, 1 do
        VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
          node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created block's attribute value should equal with the node block's attribute value" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x3e8",
          number: "0x0",
          start_number: "0x0"
        )
      )
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        local_block = node_data_processor.process_block(node_block)

        node_block = node_block.to_h.deep_stringify_keys
        formatted_node_block = format_node_block(node_block)
        epoch_info = CkbUtils.get_epoch_info(formatted_node_block["epoch"])
        formatted_node_block["start_number"] = epoch_info.start_number
        formatted_node_block["length"] = epoch_info.length

        local_block_hash = local_block.attributes.select { |attribute| attribute.in?(%w(compact_target block_hash number parent_hash nonce timestamp transactions_root proposals_hash uncles_hash version proposals epoch start_number length dao)) }
        local_block_hash["hash"] = local_block_hash.delete("block_hash")
        local_block_hash["number"] = local_block_hash["number"]
        local_block_hash["version"] = local_block_hash["version"]
        local_block_hash["epoch"] = local_block_hash["epoch"]
        local_block_hash["timestamp"] = local_block_hash["timestamp"]

        assert_equal formatted_node_block.sort, local_block_hash.sort
      end
    end

    test "#process_block created block's proposals_count should equal with the node block's proposals size" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)

        local_block = node_data_processor.process_block(node_block)

        assert_equal node_block.proposals.size, local_block.proposals_count
      end
    end

    test "#process_block should generate miner's address when cellbase has witnesses" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x07d0",
          number: "0x0",
          start_number: "0x0"
        )
      )
      VCR.use_cassette("blocks/11") do
        node_block = CkbSync::Api.instance.get_block_by_number(11)
        local_block = node_data_processor.process_block(node_block)
        expected_miner_hash = CkbUtils.miner_hash(node_block.transactions.first)
        expected_miner_address = Address.find_by(address_hash: expected_miner_hash)

        assert expected_miner_hash, local_block.miner_hash
        assert expected_miner_address, local_block.miner_address
      end
    end

    test "#process_block should generate miner's lock when cellbase has witnesses" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x07d0",
          number: "0x0",
          start_number: "0x0"
        )
      )
      VCR.use_cassette("blocks/11") do
        node_block = CkbSync::Api.instance.get_block_by_number(11)
        expected_miner_lock_hash = CkbUtils.miner_lock_hash(node_block.transactions.first)
        block = node_data_processor.process_block(node_block)

        assert_equal expected_miner_lock_hash, block.miner_lock_hash
      end
    end

    test "#process_block generated block's total_cell_capacity should equal to the sum of transactions output capacity" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)

        local_block = node_data_processor.process_block(node_block)
        expected_total_capacity = CkbUtils.total_cell_capacity(node_block.transactions)

        assert_equal expected_total_capacity, local_block.total_cell_capacity
      end
    end

    test "#process_block generated block should has correct reward" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        cellbase = node_block.transactions.first
        local_block = node_data_processor.process_block(node_block)

        assert_equal  CkbUtils.base_reward(node_block.header.number, node_block.header.epoch, cellbase), local_block.reward
      end
    end

    test "#process_block generated block should has correct primary reward" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)

        local_block = node_data_processor.process_block(node_block)

        assert_equal CkbUtils.base_reward(node_block.header.number, node_block.header.epoch, node_block.transactions.first), local_block.primary_reward
      end
    end

    test "#process_block generated block should has correct secondary reward" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)

        local_block = node_data_processor.process_block(node_block)

        assert_equal 0, local_block.secondary_reward
      end
    end

    test "#process_block generated block should has correct cell consumed" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)

        local_block = node_data_processor.process_block(node_block)

        assert_equal CkbUtils.block_cell_consumed(node_block.transactions), local_block.cell_consumed
      end
    end

    test "#process_block should create uncle_blocks" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_block_uncle_blocks = node_block.uncles

        assert_difference -> { UncleBlock.count }, node_block_uncle_blocks.size do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created uncle_block's attribute value should equal with the node uncle_block's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_uncle_blocks = node_block.uncles.map { |uncle| uncle.to_h.deep_stringify_keys }
        formatted_node_uncle_blocks = node_uncle_blocks.map { |uncle_block| format_node_block(uncle_block).sort }

        local_block = node_data_processor.process_block(node_block)
        local_uncle_blocks =
          local_block.uncle_blocks.map do |uncle_block|
            uncle_block =
              uncle_block.attributes.select do |attribute|
                attribute.in?(%w(compact_target block_hash number parent_hash nonce timestamp transactions_root proposals_hash uncles_count uncles_hash version proposals epoch dao))
              end
            uncle_block["hash"] = uncle_block.delete("block_hash")
            uncle_block.sort
          end

        assert_equal formatted_node_uncle_blocks.sort, local_uncle_blocks.sort
      end
    end

    test "#process_block created unlce_block's proposals_count should equal with the node uncle_block's proposals size" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_uncle_blocks = node_block.uncles
        node_uncle_blocks_count = node_uncle_blocks.reduce(0) { |memo, uncle_block| memo + uncle_block.proposals.size }

        local_block = node_data_processor.process_block(node_block)
        local_uncle_blocks = local_block.uncle_blocks
        local_uncle_blocks_count = local_uncle_blocks.reduce(0) { |memo, uncle_block| memo + uncle_block.proposals_count }

        assert_equal node_uncle_blocks_count, local_uncle_blocks_count
      end
    end

    test "#process_block should create ckb_transactions" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_block_transactions = node_block.transactions

        assert_difference -> { CkbTransaction.count }, node_block_transactions.count do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created block's ckb_transactions_count should equal to transactions count" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)

        local_block = node_data_processor.process_block(node_block)

        assert_equal node_block.transactions.size, local_block.ckb_transactions_count
      end
    end

    test "#process_block created ckb_transaction's attribute value should equal with the node commit_transaction's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_block_transactions = node_block.transactions
        formatted_node_block_transactions = node_block_transactions.map { |commit_transaction| format_node_block_commit_transaction(commit_transaction).sort }

        local_block = node_data_processor.process_block(node_block)
        local_ckb_transactions =
          local_block.ckb_transactions.map do |ckb_transaction|
            ckb_transaction = ckb_transaction.attributes.select { |attribute| attribute.in?(%w(tx_hash cell_deps header_deps version witnesses)) }
            ckb_transaction["hash"] = ckb_transaction.delete("tx_hash")
            ckb_transaction["version"] = ckb_transaction["version"]
            ckb_transaction["header_deps"] = [] if ckb_transaction["header_deps"].blank?
            ckb_transaction.sort
          end

        assert_equal formatted_node_block_transactions, local_ckb_transactions
      end
    end

    test "#process_block should create cell_inputs" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_block_transactions = node_block.transactions
        node_cell_inputs_count = node_block_transactions.reduce(0) { |memo, commit_transaction| memo + commit_transaction.inputs.size }

        assert_difference -> { CellInput.count }, node_cell_inputs_count do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test ".save_block created cell_inputs's attribute value should equal with the node cell_inputs's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_transactions = node_block.transactions.map(&:to_h).map(&:deep_stringify_keys)
        node_block_cell_inputs = node_transactions.map do |commit_transaction|
          commit_transaction["inputs"].each do |input|
            input["previous_output"]["index"] = input["previous_output"]["index"].hex
            input["since"] = input["since"].hex
            input["previous_output"] = input["previous_output"].sort
          end.map(&:sort)
        end.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_cell_inputs = local_block_transactions.map { |commit_transaction| commit_transaction.cell_inputs.map { |cell_input|
          cell_input.previous_output = cell_input.previous_output.sort
          cell_input.attributes.select { |attribute| attribute.in?(%(previous_output since)) }.sort
        } }.flatten

        assert_equal node_block_cell_inputs, local_block_cell_inputs
      end
    end

    test "#process_block should create cell_outputs" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_block_transactions = node_block.transactions
        node_cell_outputs_count = node_block_transactions.reduce(0) { |memo, commit_transaction| memo + commit_transaction.outputs.size }

        assert_difference -> { CellOutput.count }, node_cell_outputs_count do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created cell_outputs's attribute value should equal with the node cell_outputs's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_block_transactions = node_block.transactions
        node_block_cell_outputs = node_block_transactions.map { |commit_transaction| commit_transaction.to_h.deep_stringify_keys["outputs"].map { |output| format_node_block_cell_output(output).sort } }.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_cell_outputs = local_block_transactions.map { |commit_transaction|
          commit_transaction.cell_outputs.map do |cell_output|
            attributes = cell_output.attributes
            attributes["capacity"] = attributes["capacity"]
            attributes.select { |attribute| attribute == "capacity" }.sort
          end
        }.flatten

        assert_equal node_block_cell_outputs, local_block_cell_outputs
      end
    end

    test "cell output's data should equal with transaction's outputs_data" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_transaction = node_block.transactions.first
        node_transaction.outputs_data = %w(0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063 0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815062)
        local_block = node_data_processor.process_block(node_block)
        expected_data = local_block.cell_outputs.order(:id).pluck(:data)

        assert_equal expected_data, ["0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063"]
      end
    end

    test "#process_block created cell_outputs's cell_type should be equal to normal when cell is not dao cell" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        local_block = node_data_processor.process_block(node_block)

        assert_equal ["normal"], local_block.cell_outputs.pluck(:cell_type).uniq
      end
    end

    test "#process_block created cell_outputs's cell_type should be equal to dao when cell is dao cell and use dao code hash" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_output = node_block.transactions.first.outputs.first
        node_output.type = CKB::Types::Script.new(code_hash: ENV["DAO_CODE_HASH"], args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3")
        local_block = node_data_processor.process_block(node_block)

        assert_equal ["dao"], local_block.cell_outputs.pluck(:cell_type).uniq
      end
    end

    test "#process_block created cell_outputs's cell_type should be equal to dao when cell is dao cell and use dao type hash" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_output = node_block.transactions.first.outputs.first
        node_output.type = CKB::Types::Script.new(code_hash: ENV["DAO_TYPE_HASH"], args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3")
        local_block = node_data_processor.process_block(node_block)

        assert_equal ["dao"], local_block.cell_outputs.pluck(:cell_type).uniq
      end
    end

    test "#process_block should create addresses for cell_output" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        locks = node_block.transactions.map(&:outputs).flatten.map(&:lock)
        local_block = node_data_processor.process_block(node_block)
        expected_lock_address = locks.map { |lock| Address.find_or_create_address(lock) }

        assert_equal expected_lock_address, local_block.cell_outputs.map(&:address)
      end
    end

    test "#process_block should create addresses for ckb transaction" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        locks = node_block.transactions.map(&:outputs).flatten.map(&:lock)
        local_block = node_data_processor.process_block(node_block)
        expected_lock_address = locks.map { |lock| Address.find_or_create_address(lock) }

        assert_equal expected_lock_address, local_block.ckb_transactions.map(&:addresses).flatten
      end
    end

    test "#process_block should create lock_scripts for output" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        expected_lock_scripts = node_block.transactions.map(&:outputs).flatten.map(&:lock).map(&:to_h)
        local_block = node_data_processor.process_block(node_block)
        actual_lock_scripts = local_block.cell_outputs.map { |cell_output| CKB::Types::Script.new(code_hash: cell_output.lock_script.code_hash, args: cell_output.lock_script.args, hash_type: "type") }.map(&:to_h)

        assert_equal expected_lock_scripts, actual_lock_scripts
      end
    end

    test "#process_block created lock_script's attribute value should equal with the node lock_script's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_block_transactions = node_block.transactions
        node_block_lock_scripts = node_block_transactions.map { |commit_transaction| commit_transaction.to_h.deep_stringify_keys["outputs"].map { |output| output["lock"] }.sort }.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_lock_scripts = local_block_transactions.map { |commit_transaction| commit_transaction.cell_outputs.map { |cell_output| cell_output.lock_script.attributes.select { |attribute| attribute.in?(%w(args code_hash hash_type)) } }.sort }.flatten

        assert_equal node_block_lock_scripts, local_block_lock_scripts
      end
    end

    test "#process_block should create type_scripts" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_block_transactions = node_block.transactions
        node_cell_outputs = node_block_transactions.map(&:outputs).flatten
        node_cell_outputs_with_type_script = node_cell_outputs.select { |cell_output| cell_output.type.present? }

        assert_difference -> { TypeScript.count }, node_cell_outputs_with_type_script.size do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created type_script's attribute value should equal with the node type_script's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        fake_node_block_with_type_script(node_block)
        node_block_transactions = node_block.transactions
        node_block_type_scripts = node_block_transactions.map { |commit_transaction| commit_transaction.to_h.deep_stringify_keys["outputs"].map { |output| output["type"] }.sort }.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_type_scripts = local_block_transactions.map { |commit_transaction| commit_transaction.cell_outputs.map { |cell_output| cell_output.type_script.attributes.select { |attribute| attribute.in?(%w(args code_hash hash_type)) } }.sort }.flatten

        assert_equal node_block_type_scripts, local_block_type_scripts
      end
    end

    test "#process_block should update block's total transaction fee" do
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)
        local_block = node_data_processor.process_block(node_block)

        assert_equal 10**8 * 3, local_block.reload.total_transaction_fee
      end
    end

    test "#process_block should update block's contained addresses's transactions count even if fee is a negative number" do
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, capacity: 4 * 10**8)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)

        local_block = node_data_processor.process_block(node_block)

        assert_equal 4, local_block.contained_addresses.map(&:ckb_transactions).flatten.count
      end
    end

    test "#process_block should update block's contained addresses's info even if raise RPCError " do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).raises(CKB::RPCError)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        local_block = node_data_processor.process_block(node_block)

        assert_equal 4, local_block.contained_addresses.map(&:ckb_transactions).flatten.count
      end
    end

    test "#process_block should create dao_event which event_type is deposit_to_dao when output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoEvent.where(event_type: "deposit_to_dao").count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should create dao_event which event_type is new_dao_depositor when output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
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
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_deposit_transaction(node_block)
        output = tx.outputs.first
        address = Address.find_or_create_address(output.lock)

        assert_difference -> { address.reload.dao_deposit }, 10**8 * 1000 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should update dao contract total deposits when dao_event is deposit_to_dao and output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoContract.default_contract.total_deposit }, 10**8 * 1000 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should update dao contract deposit transactions count when dao_event is deposit_to_dao and output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoContract.default_contract.deposit_transactions_count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should update dao contract depositors count when dao_event is new_dao_depositor and output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoContract.default_contract.depositors_count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end

      assert_not_empty DaoEvent.where(event_type: "new_dao_depositor")
    end

    test "#process_block should update dao contract total depositors count when dao_event is new_dao_depositor and output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)

        assert_difference -> { DaoContract.default_contract.total_depositors_count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should not update dao contract total depositors count when depositors is already has been recorded" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      address = create(:address)
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, capacity: 10 ** 8 * 1000, address: address)
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block, capacity: 10 ** 8 * 1000, address: address)
      tx1 = node_block.transactions.first
      output1 = tx1.outputs.first
      output1.type = CKB::Types::Script.new(args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type", code_hash: ENV["DAO_TYPE_HASH"])
      output1.capacity = 10**8 * 1000
      tx1.outputs << output1
      tx1.outputs_data << "0x"

      assert_difference -> { DaoContract.default_contract.total_depositors_count }, 1 do
        node_data_processor.process_block(node_block)
      end
    end

    test "#process_block should not update dao contract depositors count when depositors is already has been recorded" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      address = create(:address)
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, capacity: 10 ** 8 * 1000, address: address)
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block, capacity: 10 ** 8 * 1000, address: address)
      tx1 = node_block.transactions.first
      output1 = tx1.outputs.first
      output1.type = CKB::Types::Script.new(args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type", code_hash: ENV["DAO_TYPE_HASH"])
      output1.capacity = 10**8 * 1000
      tx1.outputs << output1
      tx1.outputs_data << "0x"

      assert_difference -> { DaoContract.default_contract.depositors_count }, 1 do
        node_data_processor.process_block(node_block)
      end
    end

    test "#process_block should create dao_event which event_type is withdraw_from_dao when previous output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x174876ebe8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_withdraw_transaction(node_block)

        assert_difference -> { DaoEvent.where(event_type: "withdraw_from_dao").count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should create dao_event which event_type is issue subsidy when previous output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x174876ebe8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_withdraw_transaction(node_block)

        assert_difference -> { DaoEvent.where(event_type: "issue_subsidy").count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should create dao_event which event_type is take away all deposit when previous output is a dao cell and address subsidy change to zero" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x174876ebe8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)

        assert_difference -> { DaoEvent.where(event_type: "take_away_all_deposit").count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should increase dao contract withdraw transactions count when previous output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x174876ebe8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_withdraw_transaction(node_block)

        assert_difference -> { DaoContract.default_contract.withdraw_transactions_count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should decrease dao contract total deposit when previous output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x174876ebe8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        withdraw_amount = tx.cell_outputs.dao.first.capacity
        DaoContract.default_contract.update(total_deposit: withdraw_amount)

        assert_difference -> { DaoContract.default_contract.total_deposit }, -withdraw_amount do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should increase dao contract subsidy granted when previous output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x174876ebe8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        withdraw_amount = tx.cell_outputs.dao.first.capacity

        assert_difference -> { DaoContract.default_contract.reload.subsidy_granted }, "0x174876ebe8".hex - withdraw_amount do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should decrease dao contract depositors count when previous output is a dao cell and address subsidy change to zero" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x174876ebe8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)
        DaoContract.default_contract.update(depositors_count: 1)

        assert_difference -> { DaoContract.default_contract.reload.depositors_count }, -1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should decrease address deposit when previous output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x174876ebe8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)

        assert_difference -> { address.reload.dao_deposit }, -output.capacity do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should increase address subsidy when previous output is a dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x174876ebe8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        tx = fake_dao_withdraw_transaction(node_block)
        withdraw_amount = tx.cell_outputs.dao.first.capacity
        output = tx.cell_outputs.first
        address = output.address
        address.update(dao_deposit: output.capacity)

        assert_difference -> { address.reload.subsidy }, "0x174876ebe8".hex - withdraw_amount do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should update cell status" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)

        assert_difference -> { CellOutput.dead.count }, 2 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should fill all cell input's previous cell output id without cellbase's cell input" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)
        local_block = node_data_processor.process_block(node_block)

        assert_empty local_block.cell_inputs.where(from_cell_base: false, previous_cell_output_id: nil)
      end
    end

    test "#process_block should update current block's miner address pending reward blocks count" do
      prepare_node_data(24)
      VCR.use_cassette("blocks/25", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(25)
        cellbase = node_block.transactions.first
        lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
        miner_address = Address.find_or_create_address(lock_script)

        assert_difference -> { miner_address.reload.pending_reward_blocks_count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should update abandoned block's contained address's transactions count" do
      prepare_node_data(12)
      local_block = Block.find_by(number: 12)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/13") do
        assert_difference -> { local_block.contained_addresses.map(&:ckb_transactions).flatten.count }, -1 do
          node_data_processor.call
        end
      end
    end

    test "#process_block should update abandoned block's contained address's balance" do
      prepare_node_data(12)
      local_block = Block.find_by(number: 12)
      balance_diff = local_block.ckb_transactions.first.outputs.first.capacity
      origin_balance = local_block.contained_addresses.sum(:balance)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/12", record: :new_episodes) do
        new_local_block = node_data_processor.call

        assert_equal origin_balance - balance_diff, new_local_block.contained_addresses.sum(:balance)
      end
    end

    test "should let the local tip block miner's pending reward blocks count increase by one" do
      prepare_node_data(24)
      miner_address = nil
      VCR.use_cassette("blocks/25", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(25)
        cellbase = node_block.transactions.first
        lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
        miner_address = Address.find_or_create_address(lock_script)
      end

      VCR.use_cassette("blocks/25", record: :new_episodes) do
        assert_difference -> { miner_address.reload.pending_reward_blocks_count }, 1 do
          node_data_processor.call
        end
      end
    end

    test "should change the local tip block's target block reward status to issued when there is the target block" do
      prepare_node_data(12)
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        local_block = node_data_processor.call

        assert_equal "issued", local_block.target_block_reward_status
      end
    end

    test "should update the target block reward to the sum of primary and secondary when there is the target block" do
      prepare_node_data(12)
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        local_block = node_data_processor.call
        target_block = local_block.target_block
        block_header = Struct.new(:hash, :number)
        expected_reward = CkbUtils.block_reward(block_header.new(local_block.block_hash, local_block.number))

        assert_equal expected_reward, target_block.reward
      end
    end

    test "should update the target block primary reward when there is the target block" do
      prepare_node_data(12)
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        local_block = node_data_processor.call
        target_block = local_block.target_block
        block_header = Struct.new(:hash, :number)
        cellbase_output_capacity_details = CkbSync::Api.instance.get_cellbase_output_capacity_details(local_block.block_hash)
        expected_primary_reward = CkbUtils.primary_reward(block_header.new(local_block.block_hash, local_block.number), cellbase_output_capacity_details)

        assert_equal expected_primary_reward, target_block.primary_reward
      end
    end

    test "should update the target block secondary reward when there is the target block" do
      prepare_node_data(12)
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        local_block = node_data_processor.call
        target_block = local_block.target_block
        block_header = Struct.new(:hash, :number)
        cellbase_output_capacity_details = CkbSync::Api.instance.get_cellbase_output_capacity_details(local_block.block_hash)
        expected_secondary_reward = CkbUtils.secondary_reward(block_header.new(local_block.block_hash, local_block.number), cellbase_output_capacity_details)

        assert_equal expected_secondary_reward, target_block.secondary_reward
      end
    end

    test "should do nothing on the local tip block's target block reward status when there is no target block" do
      prepare_node_data(9)
      local_block = Block.find_by(number: 9)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_no_changes -> { local_block.reload.target_block_reward_status } do
          node_data_processor.call
        end
      end
    end

    test "should update the local tip block target block's received tx fee when there is the target block" do
      prepare_node_data(12)
      target_block = Block.find_by(number: 2)
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        assert_changes -> { target_block.reload.received_tx_fee }, from: 0, to: 20 do
          node_data_processor.call
        end
      end
    end

    test "should do nothing on the local tip block target block's received tx fee when there is no target block" do
      prepare_node_data(9)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_nothing_raised do
          node_data_processor.call
        end
      end
    end

    test "should change the local tip block target block' reward status to issued when there is the target block" do
      prepare_node_data(12)
      target_block = Block.find_by(number: 2)
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        assert_changes -> { target_block.reload.reward_status }, from: "pending", to: "issued" do
          node_data_processor.call
        end
      end
    end

    test "should do nothing on the local tip block target block's reward status when there is no target block" do
      prepare_node_data(9)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_nothing_raised do
          node_data_processor.call
        end
      end
    end

    test "should change the local tip block target block' received_tx_fee_status to issued when there is the target block" do
      prepare_node_data(12)
      target_block = Block.find_by(number: 2)
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        assert_changes -> { target_block.reload.received_tx_fee_status }, from: "pending", to: "calculated" do
          node_data_processor.call
        end
      end
    end

    test "should do nothing on the local tip block target block's received_tx_fee_status when there is no target block" do
      prepare_node_data(9)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_nothing_raised do
          node_data_processor.call
        end
      end
    end

    test "cellbase's display inputs should contain target block number" do
      prepare_node_data(11)
      CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
        CKB::Types::BlockReward.new(
          total: "0x174876e800",
          primary: "0x174876e800",
          secondary: "0x0",
          tx_fee: "0x0",
          proposal_reward: "0x0"
        )
      )
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x07d0",
          number: "0x0",
          start_number: "0x0"
        )
      )
      VCR.use_cassette("blocks/12") do
        assert_difference "Block.count", 1 do
          node_block = CkbSync::Api.instance.get_block_by_number(12)
          node_data_processor.process_block(node_block)
          block = Block.last
          cellbase = Cellbase.new(block)
          expected_cellbase_display_inputs = [{ id: nil, from_cellbase: true, capacity: nil, address_hash: nil, target_block_number: cellbase.target_block_number, generated_tx_hash: block.cellbase.tx_hash }]

          assert_equal expected_cellbase_display_inputs, block.cellbase.display_inputs
        end
      end
    end

    test "generated transactions should has correct display output" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
          CKB::Types::BlockReward.new(
            total: "0x174876e800",
            primary: "0x174876e800",
            secondary: "0x0",
            tx_fee: "0x0",
            proposal_reward: "0x0"
          )
        )
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        local_block = node_data_processor.process_block(node_block)

        local_ckb_transactions = local_block.ckb_transactions
        local_block_cell_outputs = local_ckb_transactions.map(&:display_outputs).flatten
        output = local_ckb_transactions.first.outputs.order(:id).first
        cellbase = Cellbase.new(local_block)
        expected_display_outputs = [{ id: output.id, capacity: output.capacity, address_hash: output.address_hash, target_block_number: cellbase.target_block_number, base_reward: cellbase.base_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward, status: "live", consumed_tx_hash: nil }]

        assert_equal expected_display_outputs, local_block_cell_outputs
      end
    end

    test "genesis block's cellbase display outputs should have multiple cells" do
      CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
        CKB::Types::BlockReward.new(
          total: "0x174876e800",
          primary: "0x174876e800",
          secondary: "0x0",
          tx_fee: "0x0",
          proposal_reward: "0x0"
        )
      )
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x07d0",
          number: "0x0",
          start_number: "0x0"
        )
      )
      VCR.use_cassette("genesis_block") do
        node_block = CkbSync::Api.instance.get_block_by_number(0)
        node_data_processor.process_block(node_block)

        block = Block.last
        cellbase = Cellbase.new(block)
        expected_cellbase_display_outputs =
          block.cellbase.cell_outputs.order(:id).map do |cell_output|
            consumed_tx_hash = cell_output.live? ? nil : cell_output.consumed_by.tx_hash
            { id: cell_output.id, capacity: cell_output.capacity, address_hash: cell_output.address_hash, target_block_number: cellbase.target_block_number, base_reward: cellbase.base_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward, status: cell_output.status, consumed_tx_hash: consumed_tx_hash }
          end

        assert_equal expected_cellbase_display_outputs, block.cellbase.display_outputs
      end
    end

    test "cellbase's display outputs should contain block reward commit reward, proposal reward and secondary reward" do
      prepare_node_data(11)
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x07d0",
          number: "0x0",
          start_number: "0x0"
        )
      )
      CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
        CKB::Types::BlockReward.new(
          total: "0x174876e800",
          primary: "0x174876e800",
          secondary: "0x0",
          tx_fee: "0x0",
          proposal_reward: "0x0"
        )
      )
      VCR.use_cassette("blocks/12") do
        assert_difference "Block.count", 1 do
          node_block = CkbSync::Api.instance.get_block_by_number(12)
          node_data_processor.process_block(node_block)

          block = Block.last
          cellbase = Cellbase.new(block)
          cell_output = block.cellbase.cell_outputs.first
          expected_cellbase_display_outputs = [{ id: cell_output.id, capacity: cell_output.capacity, address_hash: cell_output.address_hash, target_block_number: cellbase.target_block_number, base_reward: cellbase.base_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward, status: "live", consumed_tx_hash: nil }]

          assert_equal expected_cellbase_display_outputs, block.cellbase.display_outputs
        end
      end
    end

    test "should delete all uncle blocks under the existing block when it is invalid" do
      prepare_node_data(HAS_UNCLES_BLOCK_NUMBER)
      local_block = Block.find_by(number: HAS_UNCLES_BLOCK_NUMBER)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      assert_not_empty local_block.uncle_blocks

      VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}", record: :new_episodes) do
        assert_changes -> { local_block.uncle_blocks.count }, from: local_block.uncle_blocks.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should delete all ckb transactions under the existing block when it is invalid" do
      prepare_node_data(9)
      local_block = Block.find_by(number: 9)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      assert_not_empty local_block.ckb_transactions

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_changes -> { local_block.ckb_transactions.count }, from: local_block.ckb_transactions.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should delete all cell inputs under the existing block when it is invalid" do
      prepare_node_data(9)
      local_block = Block.find_by(number: 9)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      assert_not_empty local_block.cell_inputs

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_changes -> { local_block.cell_inputs.count }, from: local_block.cell_inputs.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should delete all cell outputs under the existing block when it is invalid" do
      prepare_node_data(19)
      local_block = Block.find_by(number: 19)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      assert_not_empty local_block.cell_outputs

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_changes -> { CellOutput.where(block: local_block).count }, from: CellOutput.where(block: local_block).count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should delete all lock script under the existing block when it is invalid" do
      prepare_node_data(19)
      local_block = Block.find_by(number: 19)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      origin_lock_scripts = local_block.cell_outputs.map(&:lock_script)

      assert_not_empty origin_lock_scripts

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_changes -> { CellOutput.where(block: local_block).map(&:lock_script).count }, from: origin_lock_scripts.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should delete all type script under the existing block when it is invalid" do
      prepare_node_data(19)
      local_block = Block.find_by(number: 19)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      origin_type_scripts = local_block.cell_outputs.map(&:type_script)

      assert_not_empty origin_type_scripts

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_changes -> { CellOutput.where(block: local_block).map(&:type_script).count }, from: origin_type_scripts.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should do nothing when target block is not exist" do
      prepare_node_data
      local_block = Block.find_by(number: 30)
      local_block.update(number: 100_000_000)

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_nil node_data_processor.call
      end
    end

    test "should process the genesis block correctly when there is no local block" do
      VCR.use_cassette("genesis_block", record: :new_episodes) do
        assert_difference -> { Block.count }, 1 do
          local_block = node_data_processor.call

          assert_equal 0, local_block.number
        end
      end
    end

    test "should update abandoned block's contained address transactions count" do
      prepare_node_data(19)
      local_block = Block.find_by(number: 19)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { local_block.contained_addresses.map(&:ckb_transactions).flatten.count }, -1 do
          node_data_processor.call
        end
      end
    end

    test "should update abandoned block's contained address's balance" do
      prepare_node_data(19)
      local_block = Block.find_by(number: 19)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      ckb_transaction_ids = local_block.ckb_transactions.pluck(:id)
      balance_diff = CellOutput.where(ckb_transaction_id: ckb_transaction_ids).sum(:capacity)
      contained_address = local_block.contained_addresses

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { contained_address.sum(:balance) }, -balance_diff do
          node_data_processor.call
        end
      end
    end

    test "should change abandoned block target block's received tx fee to zero when there is the target block" do
      prepare_node_data(22)
      local_block = Block.find_by(number: 22)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      target_block = local_block.target_block
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        assert_changes -> { target_block.reload.received_tx_fee }, from: target_block.received_tx_fee, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should do nothing on abandoned block target block's received tx fee when there is no target block" do
      prepare_node_data(19)
      local_block = Block.find_by(number: 19)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_nothing_raised do
          node_data_processor.call
        end
      end
    end

    test "should change abandoned block target block' reward status to pending when there is the target block" do
      prepare_node_data(22)
      local_block = Block.find_by(number: 22)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      target_block = local_block.target_block
      VCR.use_cassette("blocks/12") do
        assert_changes -> { target_block.reload.reward_status }, from: "issued", to: "pending" do
          node_data_processor.call
        end
      end
    end

    test "should do nothing on abandoned block target block's reward status when there is no target block" do
      prepare_node_data(19)
      local_block = Block.find_by(number: 19)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_nothing_raised do
          node_data_processor.call
        end
      end
    end

    test "should change abandoned block target block' received_tx_fee_status to pending when there is the target block" do
      prepare_node_data(22)
      local_block = Block.find_by(number: 22)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      target_block = local_block.target_block
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        assert_changes -> { target_block.reload.received_tx_fee_status }, from: "calculated", to: "pending" do
          node_data_processor.call
        end
      end
    end

    test "should do nothing on abandoned block target block's received_tx_fee_status when there is no target block" do
      prepare_node_data(19)
      local_block = Block.find_by(number: 19)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_nothing_raised do
          node_data_processor.call
        end
      end
    end

    private

    def node_data_processor
      CkbSync::NodeDataProcessor.new
    end

    def fake_dao_withdraw_transaction(node_block)
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, cell_type: "dao", capacity: 10 ** 8 * 1000)
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)
      tx = node_block.transactions.last
      tx.header_deps = ["0x0b3e980e4e5e59b7d478287e21cd89ffdc3ff5916ee26cf2aa87910c6a504d61"]
      tx.witnesses = %w(0x8ae8061ec879d66c0f3996ab60d7c2a21094b8739817beddaea1e28d3620a70a21497a692581ca352631a67f3f6659a7c47d9a0c6c2def79d3e39440918a66fef 0x4e52933358ae2f26863b8c1c71bf20f17489328820f8f2cd84a070069f10ceef784bc3693c3c51b93475a7b5dbf652ba6532d0580ecc1faf909f9fd53c5f6405000000000000000000)

      ckb_transaction1
    end

    def fake_dao_deposit_transaction(node_block)
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, capacity: 10 ** 8 * 1000)
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)
      tx = node_block.transactions.first
      output = tx.outputs.first
      output.type = CKB::Types::Script.new(args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type", code_hash: ENV["DAO_TYPE_HASH"])
      output.capacity = 10**8 * 1000

      tx
    end
  end
end
