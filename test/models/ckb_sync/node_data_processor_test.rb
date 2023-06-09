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
      CkbSync::Api.any_instance.stubs(:get_block_cycles).returns(
        [
          "0x100", "0x200", "0x300", "0x400", "0x500", "0x600", "0x700", "0x800", "0x900"
        ]
      )
      create(:table_record_count, :block_counter)
      create(:table_record_count, :ckb_transactions_counter)
      CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
      GenerateStatisticsDataWorker.any_instance.stubs(:perform).returns(true)
      CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
    end

    test "#process_block should create one block" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        assert_difference -> { Block.count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should create one block with miner message" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        node_block.transactions.first.witnesses = ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce80114000000da648442dbb7347e467d1d09da13e5cd3a0ef0e104000000deadbeef"]
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        block = node_data_processor.process_block(node_block)
        assert_equal "0xdeadbeef", block.miner_message
      end
    end

    test "should update table_record_counts block count after block has been processed" do
      block_counter = TableRecordCount.find_or_initialize_by(table_name: "blocks")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        assert_difference -> { block_counter.reload.count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "should update table_record_counts ckb transactions count after block has been processed" do
      ckb_transaction_counter = TableRecordCount.find_or_initialize_by(table_name: "ckb_transactions")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        assert_difference -> { ckb_transaction_counter.reload.count }, node_block.transactions[1..-1].count do
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
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        local_block = node_data_processor.process_block(node_block)

        node_block = node_block.to_h.deep_stringify_keys
        formatted_node_block = format_node_block(node_block)
        epoch_info = CkbUtils.get_epoch_info(formatted_node_block["epoch"])
        formatted_node_block["start_number"] = epoch_info.start_number
        formatted_node_block["length"] = epoch_info.length

        local_block_hash =
          local_block.attributes.select do |attribute|
            attribute.in?(%w(
                            compact_target block_hash number parent_hash nonce timestamp transactions_root proposals_hash
                            extra_hash version proposals epoch start_number length dao
                          ))
          end
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
        create(:block, :with_block_hash, number: node_block.header.number - 1)

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
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        local_block = node_data_processor.process_block(node_block)
        expected_miner_hash = CkbUtils.miner_hash(node_block.transactions.first)
        expected_miner_address = Address.find_by_address_hash(expected_miner_hash)

        assert expected_miner_hash, local_block.miner_hash
        assert expected_miner_address, local_block.miner_address
      end
    end

    test "#process_block should change pool transaction's status to committed when it has been committed to current block" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x07d0",
          number: "0x0",
          start_number: "0x0"
        )
      )
      VCR.use_cassette("blocks/11") do
        tx = create(:pending_transaction)
        node_block = CkbSync::Api.instance.get_block_by_number(11)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_block.transactions.first.hash = tx.tx_hash
        assert_changes -> { tx.reload.tx_status }, from: "pending", to: "committed" do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should not change pool transaction's status to committed when it has not been committed to current block" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          compact_target: "0x1000",
          length: "0x07d0",
          number: "0x0",
          start_number: "0x0"
        )
      )
      VCR.use_cassette("blocks/11") do
        tx = create(:pending_transaction)
        node_block = CkbSync::Api.instance.get_block_by_number(11)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        assert_no_changes -> { tx.reload.tx_status } do
          node_data_processor.process_block(node_block)
        end
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
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        expected_miner_lock_hash = CkbUtils.miner_lock_hash(node_block.transactions.first)
        block = node_data_processor.process_block(node_block)

        assert_equal expected_miner_lock_hash, block.miner_lock_hash
      end
    end

    test "#process_block generated block's total_cell_capacity should equal to the sum of transactions output capacity" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)

        local_block = node_data_processor.process_block(node_block)
        expected_total_capacity = CkbUtils.total_cell_capacity(node_block.transactions)

        assert_equal expected_total_capacity, local_block.total_cell_capacity
      end
    end

    test "#process_block generated block should has correct reward" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_block.transactions.first
        local_block = node_data_processor.process_block(node_block)

        assert_equal  CkbUtils.base_reward(node_block.header.number, node_block.header.epoch), local_block.reward
      end
    end

    test "#process_block generated block should has correct primary reward" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)

        local_block = node_data_processor.process_block(node_block)

        assert_equal CkbUtils.base_reward(node_block.header.number, node_block.header.epoch), local_block.primary_reward
      end
    end

    test "#process_block generated block should has correct secondary reward" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)

        local_block = node_data_processor.process_block(node_block)

        assert_equal 0, local_block.secondary_reward
      end
    end

    test "#process_block generated block should has correct cell consumed" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)

        local_block = node_data_processor.process_block(node_block)

        assert_equal CkbUtils.block_cell_consumed(node_block.transactions), local_block.cell_consumed
      end
    end

    test "#process_block should create uncle_blocks" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_block_uncle_blocks = node_block.uncles

        assert_difference -> { UncleBlock.count }, node_block_uncle_blocks.size do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created uncle_block's attribute value should equal with the node uncle_block's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_uncle_blocks = node_block.uncles.map { |uncle| uncle.to_h.deep_stringify_keys }
        formatted_node_uncle_blocks = node_uncle_blocks.map { |uncle_block| format_node_block(uncle_block).sort }

        local_block = node_data_processor.process_block(node_block)
        local_uncle_blocks =
          local_block.uncle_blocks.map do |uncle_block|
            uncle_block =
              uncle_block.attributes.select do |attribute|
                attribute.in?(%w(
                                compact_target block_hash number parent_hash nonce timestamp transactions_root
                                proposals_hash uncles_count extra_hash version proposals epoch dao
                              ))
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
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_uncle_blocks = node_block.uncles
        node_uncle_blocks_count = node_uncle_blocks.reduce(0) { |memo, uncle_block| memo + uncle_block.proposals.size }

        local_block = node_data_processor.process_block(node_block)
        local_uncle_blocks = local_block.uncle_blocks
        local_uncle_blocks_count =
          local_uncle_blocks.reduce(0) do |memo, uncle_block|
            memo + uncle_block.proposals_count
          end

        assert_equal node_uncle_blocks_count, local_uncle_blocks_count
      end
    end

    test "#process_block should create ckb_transactions" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_block_transactions = node_block.transactions

        assert_difference -> { CkbTransaction.count }, node_block_transactions.count do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created block's ckb_transactions_count should equal to transactions count" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)

        local_block = node_data_processor.process_block(node_block)

        assert_equal node_block.transactions.size, local_block.ckb_transactions_count
      end
    end

    test "#process_block created ckb_transaction's attribute value should equal with the node commit_transaction's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_block_transactions = node_block.transactions
        formatted_node_block_transactions =
          node_block_transactions.map do |commit_transaction|
            format_node_block_commit_transaction(commit_transaction).sort
          end

        local_block = node_data_processor.process_block(node_block)
        local_ckb_transactions =
          local_block.ckb_transactions.map do |ckb_transaction|
            attrs =
              ckb_transaction.attributes.select do |attribute|
                attribute.in?(%w(tx_hash cell_deps header_deps version witnesses))
              end
            attrs["hash"] = attrs.delete("tx_hash")
            attrs["version"] = attrs["version"].to_i
            attrs["header_deps"] = ckb_transaction.header_deps
            attrs["cell_deps"] = ckb_transaction.cell_deps
            attrs["witnesses"] = ckb_transaction.witnesses.map(&:data)
            attrs.sort
          end
        assert_equal formatted_node_block_transactions, local_ckb_transactions
      end
    end

    test "#process_block created ckb_transaction's live cell changes should equal to outputs count minus inputs count" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction,
                                  tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction,
                                  tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1,
                             tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",  block: block, capacity: 4 * 10**8)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2,
                             tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",  block: block)
        node_block_transactions = node_block.transactions

        local_block = node_data_processor.process_block(node_block)
        expected_live_cell_changes =
          node_block_transactions.each_with_index.map do |transaction, index|
            index.zero? ? 1 : transaction.outputs.count - transaction.inputs.count
          end
        assert_equal expected_live_cell_changes, local_block.ckb_transactions.order(:id).map(&:live_cell_changes)
      end
    end

    test "#process_block created ckb_transaction's capacity_involved should equal to outputs count minus inputs count" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction,
                                  tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction,
                                  tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1,
                             tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",  block: block)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2,
                             tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",  block: block)
        local_block = node_data_processor.process_block(node_block)
        expected_capacity_involved = local_block.ckb_transactions.normal.map(&:capacity_involved)

        assert_equal expected_capacity_involved, local_block.ckb_transactions.normal.map { |transaction|
                                                   transaction.inputs.sum(:capacity)
                                                 }
      end
    end

    test "#process_block created block's live cell changes should equal to sum of ckb_transaction's live cell changes" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction,
                                  tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction,
                                  tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1,
                             tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, capacity: 4 * 10**8)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2,
                             tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)

        local_block = node_data_processor.process_block(node_block)
        assert_equal local_block.live_cell_changes, local_block.ckb_transactions.sum(&:live_cell_changes)
      end
    end

    test "#process_block should create cell_inputs" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_block_transactions = node_block.transactions
        node_cell_inputs_count =
          node_block_transactions.reduce(0) do |memo, commit_transaction|
            memo + commit_transaction.inputs.size
          end

        assert_difference -> { CellInput.count }, node_cell_inputs_count do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test ".save_block created cell_inputs's attribute value should equal with the node cell_inputs's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_transactions = node_block.transactions.map(&:to_h).map(&:deep_stringify_keys)
        node_block_cell_inputs = node_transactions.map { |commit_transaction|
          commit_transaction["inputs"].map do |input|
            {
              "previous_tx_hash" => input["previous_output"]["tx_hash"] == CellOutput::SYSTEM_TX_HASH ? nil : input["previous_output"]["tx_hash"],
              "index" => input["previous_output"]["tx_hash"] == CellOutput::SYSTEM_TX_HASH ? 0 : input["previous_output"]["index"].hex,
              "since" => input["since"].hex
            }
          end
        }.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_cell_inputs = local_block_transactions.map { |commit_transaction|
          commit_transaction.cell_inputs.map do |cell_input|
            {
              "previous_tx_hash" => cell_input.previous_tx_hash,
              "index" => cell_input.previous_index,
              "since" => cell_input.since
            }
          end
        }.flatten
        # binding.pry
        assert_equal node_block_cell_inputs, local_block_cell_inputs
      end
    end

    test "#process_block should create cell_outputs" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_block_transactions = node_block.transactions
        node_cell_outputs_count =
          node_block_transactions.reduce(0) do |memo, commit_transaction|
            memo + commit_transaction.outputs.size
          end

        assert_difference -> { CellOutput.count }, node_cell_outputs_count do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created cell_outputs's attribute value should equal with the node cell_outputs's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_block_transactions = node_block.transactions
        node_block_cell_outputs = node_block_transactions.map { |commit_transaction|
          commit_transaction.to_h.deep_stringify_keys["outputs"].map do |output|
            format_node_block_cell_output(output).sort
          end
        }.flatten

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
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_transaction = node_block.transactions.first
        node_transaction.outputs_data = %w(
          0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063
          0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815062
        )
        local_block = node_data_processor.process_block(node_block)
        expected_data = local_block.cell_outputs.order(:id).pluck(:data)

        assert_equal expected_data, ["0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063"]
      end
    end

    test "#process_block created cell_outputs's cell_type should be equal to normal when cell is not dao cell" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        local_block = node_data_processor.process_block(node_block)

        assert_equal ["normal"], local_block.cell_outputs.pluck(:cell_type).uniq
      end
    end

    test "#process_block created cell_outputs's cell_type should be equal to nervos_dao_deposit_cell when cell is dao cell, output data is 8 byte 0 and use dao code hash" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        node_output.type = CKB::Types::Script.new(code_hash: Settings.dao_code_hash,
                                                  args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type")
        node_block.transactions.first.outputs_data[0] = CKB::Utils.bin_to_hex("\x00" * 8)
        local_block = node_data_processor.process_block(node_block)

        assert_equal ["nervos_dao_deposit"], local_block.cell_outputs.pluck(:cell_type).uniq
      end
    end

    test "#process_block created cell_outputs's cell_type should be equal to nervos_dao_deposit when cell is dao cell, output data is 8 byte 0 and use dao type hash" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        node_output.type = CKB::Types::Script.new(code_hash: Settings.dao_type_hash,
                                                  args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type")
        node_block.transactions.first.outputs_data[0] = CKB::Utils.bin_to_hex("\x00" * 8)
        local_block = node_data_processor.process_block(node_block)

        assert_equal ["nervos_dao_deposit"], local_block.cell_outputs.pluck(:cell_type).uniq
      end
    end

    test "#process_block created cell_outputs's cell_type should be equal to nervos_dao_withdrawing when cell is dao cell, output data is 8 byte non-zero number and use dao type hash" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        node_output.type = CKB::Types::Script.new(code_hash: Settings.dao_type_hash,
                                                  args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type")
        node_block.transactions.first.outputs_data[0] = CKB::Utils.bin_to_hex("\x02" * 8)
        local_block = node_data_processor.process_block(node_block)

        assert_equal ["nervos_dao_withdrawing"], local_block.cell_outputs.pluck(:cell_type).uniq
      end
    end

    test "#process_block should create addresses for cell_output" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        locks = node_block.transactions.map(&:outputs).flatten.map(&:lock)
        local_block = node_data_processor.process_block(node_block)
        expected_lock_address = locks.map { |lock| Address.find_or_create_address(lock, node_block.header.timestamp) }

        assert_equal expected_lock_address, local_block.cell_outputs.map(&:address)
      end
    end

    test "#process_block should create addresses for ckb transaction" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        locks = node_block.transactions.map(&:outputs).flatten.map(&:lock)
        local_block = node_data_processor.process_block(node_block)
        expected_lock_address = locks.map { |lock| Address.find_or_create_address(lock, node_block.header.timestamp) }

        assert_equal expected_lock_address,
                     Address.where(id: local_block.ckb_transactions.map(&:contained_address_ids).flatten)
      end
    end

    test "#process_block should create lock_scripts for output" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        expected_lock_scripts = node_block.transactions.map(&:outputs).flatten.map(&:lock).map(&:to_h)
        local_block = node_data_processor.process_block(node_block)
        actual_lock_scripts = local_block.cell_outputs.map { |cell_output|
          CKB::Types::Script.new(code_hash: cell_output.lock_script.code_hash, args: cell_output.lock_script.args,
                                 hash_type: "type")
        }.map(&:to_h)

        assert_equal expected_lock_scripts, actual_lock_scripts
      end
    end

    test "#process_block created lock_script's attribute value should equal with the node lock_script's attribute value" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_block_transactions = node_block.transactions
        node_block_lock_scripts = node_block_transactions.map { |commit_transaction|
          commit_transaction.to_h.deep_stringify_keys["outputs"].map { |output|
            output["lock"]
          }.sort
        }.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_lock_scripts = local_block_transactions.map { |commit_transaction|
          commit_transaction.cell_outputs.map { |cell_output|
            cell_output.lock_script.attributes.select do |attribute|
              attribute.in?(%w(args code_hash hash_type))
            end
          }.sort
        }.flatten

        assert_equal node_block_lock_scripts, local_block_lock_scripts
      end
    end

    test "#process_block should create type_scripts" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
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
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        fake_node_block_with_type_script(node_block)
        node_block_transactions = node_block.transactions
        node_block_type_scripts = node_block_transactions.map { |commit_transaction|
          commit_transaction.to_h.deep_stringify_keys["outputs"].map { |output|
            output["type"]
          }.sort
        }.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_type_scripts = local_block_transactions.map { |commit_transaction|
          commit_transaction.cell_outputs.map { |cell_output|
            cell_output.type_script.attributes.select do |attribute|
              attribute.in?(%w(args code_hash hash_type))
            end
          }.sort
        }.flatten

        assert_equal node_block_type_scripts, local_block_type_scripts
      end
    end

    test "#process_block should update block's total transaction fee" do
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction,
                                  tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction,
                                  tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        lock = create(:lock_script)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1,
                             tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, lock_script_id: lock.id)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2,
                             tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, lock_script_id: lock.id)
        local_block = node_data_processor.process_block(node_block)

        assert_equal 10**8 * 5, local_block.reload.total_transaction_fee
      end
    end

    test "#process_block should update block's contained addresses's transactions count even if fee is a negative number" do
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        block = create(:block, :with_block_hash)
        lock = node_block.transactions.last.outputs.first.lock
        lock_script = create(:lock_script, code_hash: lock.code_hash, hash_type: lock.hash_type, args: lock.args)
        addr = Address.find_or_create_address(lock, node_block.header.timestamp, lock_script.id)
        ckb_transaction1 = create(:ckb_transaction,
                                  tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, contained_address_ids: [addr.id])
        ckb_transaction2 = create(:ckb_transaction,
                                  tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, contained_address_ids: [addr.id])
        addr.update(ckb_transactions_count: 2)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1,
                             tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, capacity: 4 * 10**8, address: addr)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2,
                             tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, address: addr)

        local_block = node_data_processor.process_block(node_block)

        assert_equal 5, local_block.contained_addresses.map(&:ckb_transactions_count).flatten.sum
      end
    end

    test "#process_block should update block's contained addresses's info even if raise RPCError " do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).raises(CKB::RPCError)
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        lock = node_block.transactions.last.outputs.first.lock
        lock_script = create(:lock_script, code_hash: lock.code_hash, hash_type: lock.hash_type, args: lock.args)
        addr = Address.find_or_create_address(lock, node_block.header.timestamp, lock_script.id)
        fake_dao_deposit_transaction(node_block)

        local_block = node_data_processor.process_block(node_block)

        assert_equal 5, local_block.contained_addresses.map(&:ckb_transactions_count).flatten.sum
      end
    end

    test "should create forked event when block is invalid " do
      node_block = fake_node_block
      create(:block, :with_block_hash, number: node_block.header.number - 1, timestamp: 1557282351075)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)
        node_data_processor.process_block(node_block)
      end
      local_block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { ForkedEvent.count }, 1 do
          node_data_processor.call
        end
        assert_equal "pending", ForkedEvent.first.status
      end
    end

    test "should revert dao contract total depositors count when block is invalid and there is dao cell" do
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block
      create(:block, :with_block_hash, number: node_block.header.number - 1, timestamp: 1557282351075)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        fake_dao_deposit_transaction(node_block)
        node_data_processor.process_block(node_block)
      end
      dao_contract = DaoContract.default_contract
      local_block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { dao_contract.reload.total_depositors_count }, -1 do
          node_data_processor.call
        end

        deposit_to_dao_events = local_block.dao_events.where(event_type: "new_dao_depositor")
        assert_equal ["reverted"], deposit_to_dao_events.pluck(:status).uniq
      end
    end

    test "#process_block should update cell status" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction,
                                  tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction,
                                  tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1,
                             tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2,
                             tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)

        assert_difference -> { CellOutput.dead.count }, 2 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should fill all cell input's previous cell output id without cellbase's cell input" do
      prepare_node_data(11)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
        Rails.stubs(:cache).returns(redis_cache_store)
        Rails.cache.extend(CacheRealizer)
        node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction,
                                  tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction,
                                  tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1,
                             tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2,
                             tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)

        create(:block, :with_block_hash, number: node_block.header.number - 1)
        local_block = node_data_processor.process_block(node_block)
        assert_empty local_block.cell_inputs.where(from_cell_base: false, previous_cell_output_id: nil)
      end
    end

    test "#process_block should create mining info" do
      prepare_node_data(24)
      VCR.use_cassette("blocks/25", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(25)
        cellbase = node_block.transactions.first
        lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
        miner_address = Address.find_or_create_address(lock_script, node_block.header.timestamp)

        assert_difference -> { MiningInfo.count }, 1 do
          node_data_processor.process_block(node_block)
        end
        assert_equal "mined", MiningInfo.find_by(block_number: 25, address_id: miner_address.id).status
      end
    end

    test "should revert current block mining info when block is invalid" do
      prepare_node_data(24)
      local_block = Block.find_by(number: 24)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/25") do
        assert_changes -> { MiningInfo.find_by(block_number: 24).status }, from: "mined", to: "reverted" do
          node_data_processor.call
        end
      end
    end

    test "should revert current block miner's mined blocks count when block is invalid" do
      prepare_node_data(24)
      local_block = Block.find_by(number: 24)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      addr = create(:address)
      local_block.target_block.update(miner_hash: addr.address_hash)

      VCR.use_cassette("blocks/25") do
        assert_difference -> { local_block.miner_address.reload.mined_blocks_count }, -1 do
          node_data_processor.call
        end
      end
    end

    test "#process_block should update current block's miner address mined blocks count" do
      prepare_node_data(24)
      VCR.use_cassette("blocks/25", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(25)
        cellbase = node_block.transactions.first
        lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
        miner_address = Address.find_or_create_address(lock_script, node_block.header.timestamp)

        assert_difference -> { miner_address.reload.mined_blocks_count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should update abandoned block's contained address's transactions count" do
      prepare_node_data(12)
      local_block = Block.find_by(number: 12)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/13") do
        assert_difference -> { local_block.contained_addresses.map(&:ckb_transactions_count).flatten.sum }, -1 do
          node_data_processor.call
        end
      end
    end

    test "should recalculate table_record_counts block count when block is invalid" do
      block_counter = TableRecordCount.find_or_initialize_by(table_name: "blocks")
      prepare_node_data(12)
      local_block = Block.find_by(number: 12)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/13") do
        assert_difference -> { block_counter.reload.count }, -1 do
          node_data_processor.call
        end
      end
    end

    test "should recalculate table_record_counts ckb_transactions count when block is invalid" do
      ckb_transactions_counter = TableRecordCount.find_or_initialize_by(table_name: "ckb_transactions")

      prepare_node_data(12)
      local_block = Block.find_by(number: 12)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/13") do
        assert_difference -> { ckb_transactions_counter.reload.count }, -local_block.ckb_transactions.normal.count do
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

    test "#process_block should update block's contained address's live cells count" do
      prepare_node_data(12)
      local_block = Block.find_by(number: 12)
      origin_live_cells_count = local_block.contained_addresses.sum(:live_cells_count)
      VCR.use_cassette("blocks/13", record: :new_episodes) do
        new_local_block = node_data_processor.call

        assert_equal origin_live_cells_count + 1, new_local_block.contained_addresses.sum(:live_cells_count)

        address = new_local_block.contained_addresses.first
        snapshot = AddressBlockSnapshot.find_by(block_id: new_local_block.id, address_id: address.id)
        assert_equal snapshot.final_state["live_cells_count"], address.live_cells_count
      end
    end

    test "#process_block should update block's contained address's balance" do
      prepare_node_data(12)
      local_block = Block.find_by(number: 12)
      origin_balance = local_block.contained_addresses.sum(:balance)
      VCR.use_cassette("blocks/13") do
        node_block = CkbSync::Api.instance.get_block_by_number(13)
        lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                       args: "0x#{SecureRandom.hex(20)}")
        lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                       args: "0x#{SecureRandom.hex(20)}")
        Address.find_or_create_address(lock1, node_block.header.timestamp)
        Address.find_or_create_address(lock2, node_block.header.timestamp)
        300.times do |i|
          if i % 2 == 0
            node_block.transactions.first.outputs << CKB::Types::Output.new(capacity: 30000 * 10**8, lock: lock1)
          else
            node_block.transactions.first.outputs << CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2)
          end
          node_block.transactions.first.outputs_data << "0x"
        end
        new_local_block = node_data_processor.process_block(node_block)

        assert_equal origin_balance + new_local_block.cell_outputs.sum(:capacity),
                     new_local_block.contained_addresses.sum(:balance)

        address = new_local_block.contained_addresses.first
        snapshot = AddressBlockSnapshot.find_by(block_id: new_local_block.id, address_id: address.id)
        assert_equal snapshot.final_state["balance"], address.balance
      end
    end

    test "#process_block should update block's contained address's dao_ckb_transactions_count" do
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
      create(:cell_output, ckb_transaction: tx1,  block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1)
      create(:cell_output, ckb_transaction: tx2,  block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2)
      create(:cell_output, ckb_transaction: tx3,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3)
      create(:cell_output, ckb_transaction: tx4,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4)
      create(:cell_output, ckb_transaction: tx5,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      dao_type = CKB::Types::Script.new(code_hash: Settings.dao_type_hash, hash_type: "type", args: "0x")
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      outputs1 = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %w[0x0000000000000000 0x0000000000000000 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs1, outputs_data: %w[0x0000000000000000 0x0000000000000000 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      node_data_processor.process_block(node_block)
      address1 = Address.find_by(lock_hash: lock1.compute_hash)
      address2 = Address.find_by(lock_hash: lock2.compute_hash)
      address3 = Address.find_by(lock_hash: lock3.compute_hash)

      assert_equal 2, address1.dao_transactions_count
      assert_equal 2, address2.dao_transactions_count
      assert_equal 0, address3.dao_transactions_count
    end

    test "should recalculate block's contained address's dao_ckb_transactions_count when block is invalid" do
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      tx4 = create(:ckb_transaction, block: block2)
      tx5 = create(:ckb_transaction, block: block2)
      input_address1 = create(:address, balance: 50000 * 10**8)
      input_address2 = create(:address, balance: 60000 * 10**8)
      input_address3 = create(:address, balance: 70000 * 10**8)
      input_address4 = create(:address, balance: 70000 * 10**8)
      input_address5 = create(:address, balance: 70000 * 10**8)
      lock = create(:lock_script)
      create(:cell_output, ckb_transaction: tx1,  block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx2,  block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx3,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx4,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx5,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5, lock_script_id: lock.id)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      dao_type = CKB::Types::Script.new(code_hash: Settings.dao_type_hash, hash_type: "type", args: "0x")
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      outputs1 = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %w[0x0000000000000000 0x0000000000000000 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs1, outputs_data: %w[0x0000000000000000 0x0000000000000000 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)
      address1 = Address.find_by(lock_hash: lock1.compute_hash)
      address2 = Address.find_by(lock_hash: lock2.compute_hash)
      address3 = Address.find_by(lock_hash: lock3.compute_hash)
      CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(block.number + 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_data_processor.call
      end

      assert_equal 0, address1.reload.dao_transactions_count
      assert_equal 0, address2.reload.dao_transactions_count
      assert_equal 0, address3.reload.dao_transactions_count
    end

    test "#process_block should update abandoned block's contained address's live cells count" do
      prepare_node_data(12)
      local_block = Block.find_by(number: 12)
      origin_live_cells_count = local_block.contained_addresses.sum(:live_cells_count)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        new_local_block = node_data_processor.call

        assert_equal origin_live_cells_count - 1, new_local_block.contained_addresses.sum(:live_cells_count)
      end
    end

    test "#process_block should update abandoned block's contained address's balance occupied" do
      prepare_node_data(12)
      local_block = Block.find_by(number: 12)
      address = local_block.contained_addresses.first
      origin_balance_occupied = 300 * 10**8
      address.update(balance_occupied: origin_balance_occupied, mined_blocks_count: 1)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        new_local_block = node_data_processor.call

        assert_equal 0, new_local_block.contained_addresses.sum(:balance_occupied)
      end
    end

    test "should update the target block reward to the sum of primary and secondary when there is the target block" do
      prepare_node_data(12)
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        local_block = node_data_processor.call
        target_block = local_block.target_block
        block_economic_state = CkbSync::Api.instance.get_block_economic_state(local_block.target_block.block_hash)
        expected_reward = CkbUtils.block_reward(local_block.number, block_economic_state)

        assert_equal expected_reward, target_block.reward
      end
    end

    test "should update the target block primary reward when there is the target block" do
      prepare_node_data(12)
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        local_block = node_data_processor.call
        target_block = local_block.target_block
        block_header = Struct.new(:hash, :number)
        block_economic_state = CkbSync::Api.instance.get_block_economic_state(local_block.target_block.block_hash)
        expected_primary_reward = CkbUtils.primary_reward(local_block.target_block_number, block_economic_state)

        assert_equal expected_primary_reward, target_block.primary_reward
      end
    end

    test "should update the target block secondary reward when there is the target block" do
      prepare_node_data(12)
      VCR.use_cassette("blocks/12", record: :new_episodes) do
        local_block = node_data_processor.call
        target_block = local_block.target_block
        block_header = Struct.new(:hash, :number)
        block_economic_state = CkbSync::Api.instance.get_block_economic_state(local_block.target_block.block_hash)
        expected_secondary_reward = CkbUtils.secondary_reward(local_block.target_block_number, block_economic_state)

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
      CkbSync::Api.any_instance.stubs(:get_block_economic_state).returns(
        OpenStruct.new(miner_reward: CKB::Types::MinerReward.new(
          primary: "0x174876e800",
          secondary: "0xa",
          committed: "0xa",
          proposal: "0xa"
        ))
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
        node_block = CkbSync::Api.instance.get_block_by_number(12)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        assert_difference "Block.count", 1 do
          node_data_processor.process_block(node_block)
          block = Block.last
          cellbase = Cellbase.new(block)
          expected_cellbase_display_inputs = [
            CkbUtils.hash_value_to_s(id: nil, from_cellbase: true, capacity: nil,
                                     address_hash: nil, target_block_number: cellbase.target_block_number, generated_tx_hash: block.cellbase.tx_hash)
          ]

          assert_equal expected_cellbase_display_inputs, block.cellbase.display_inputs
        end
      end
    end

    test "generated transactions should has correct display output" do
      create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 11)
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
        CkbSync::Api.any_instance.stubs(:get_block_economic_state).returns(
          OpenStruct.new(miner_reward: CKB::Types::MinerReward.new(
            primary: "0x174876e800",
            secondary: "0xa",
            committed: "0xa",
            proposal: "0xa"
          ))
        )
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        local_block = node_data_processor.process_block(node_block)

        local_ckb_transactions = local_block.ckb_transactions
        local_block_cell_outputs = local_ckb_transactions.map(&:display_outputs).flatten
        output = local_ckb_transactions.first.outputs.order(:id).first
        cellbase = Cellbase.new(local_block)
        expected_display_outputs = [
          CkbUtils.hash_value_to_s(id: output.id, capacity: output.capacity,
                                   address_hash: output.address_hash, target_block_number: cellbase.target_block_number, base_reward: cellbase.base_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward, status: "live", consumed_tx_hash: nil)
        ]

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
      CkbSync::Api.any_instance.stubs(:get_block_economic_state).returns(
        OpenStruct.new(miner_reward: CKB::Types::MinerReward.new(
          primary: "0x174876e800",
          secondary: "0xa",
          committed: "0xa",
          proposal: "0xa"
        ))
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
            CkbUtils.hash_value_to_s(id: cell_output.id, capacity: cell_output.capacity,
                                     address_hash: cell_output.address_hash, target_block_number: cellbase.target_block_number, base_reward: cellbase.base_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward, status: cell_output.status, consumed_tx_hash: consumed_tx_hash)
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
      CkbSync::Api.any_instance.stubs(:get_block_economic_state).returns(
        OpenStruct.new(miner_reward: CKB::Types::MinerReward.new(
          primary: "0x174876e800",
          secondary: "0xa",
          committed: "0xa",
          proposal: "0xa"
        ))
      )
      VCR.use_cassette("blocks/12") do
        assert_difference "Block.count", 1 do
          node_block = CkbSync::Api.instance.get_block_by_number(12)
          node_data_processor.process_block(node_block)

          block = Block.last
          cellbase = Cellbase.new(block)
          cell_output = block.cellbase.cell_outputs.first
          expected_cellbase_display_outputs = [
            CkbUtils.hash_value_to_s(id: cell_output.id,
                                     capacity: cell_output.capacity, address_hash: cell_output.address_hash, target_block_number: cellbase.target_block_number, base_reward: cellbase.base_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward, status: "live", consumed_tx_hash: nil)
          ]

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
        assert_changes -> {
                         CellOutput.where(block: local_block).count
                       }, from: CellOutput.where(block: local_block).count, to: 0 do
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
        assert_changes -> {
                         CellOutput.where(block: local_block).map(&:lock_script).count
                       }, from: origin_lock_scripts.count, to: 0 do
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
        assert_changes -> {
                         CellOutput.where(block: local_block).map(&:type_script).count
                       }, from: origin_type_scripts.count, to: 0 do
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
      CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(0)
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
      # ApplicationRecord.connection.execute "CALL sync_full_account_book()"
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { local_block.contained_addresses.map(&:ckb_transactions_count).flatten.sum }, -1 do
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

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_difference -> { local_block.contained_addresses.sum(:balance) }, -balance_diff do
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

    test "#process_block created address's block_timestamp should be the same as block's timestamp" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        block = node_data_processor.process_block(node_block)
        address_block_timestamp = block.contained_addresses.pluck(:block_timestamp).uniq

        assert_equal [block.timestamp], address_block_timestamp
      end
    end

    test "#process_block created cell_output's block_timestamp should be the same as block's timestamp" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        block = node_data_processor.process_block(node_block)
        cell_outputs_block_timestamp = block.cell_outputs.pluck(:block_timestamp).uniq

        assert_equal [block.timestamp], cell_outputs_block_timestamp
      end
    end

    test "#process_block created cell_outputs's cell_type should be equal to udt when it is a udt cell" do
      issuer_address = create(:address)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        node_block.transactions.first.outputs_data[0] = "0x421d0000000000000000000000000000"
        node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                  args: issuer_address.lock_hash, hash_type: "type")
        create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: node_output.type.compute_hash,
                     block_timestamp: node_block.header.timestamp)
        local_block = node_data_processor.process_block(node_block)

        assert_equal ["udt"], local_block.cell_outputs.pluck(:cell_type).uniq
      end
    end

    test "#process_block created cell_outputs's cell_type should be equal to udt when it is a new udt cell" do
      Settings.sudt1_cell_type_hash = "0xc5e5dcf215925f7ef4dfaf5f4b4f105bc321c02776d6e7d52a1db3fcd9d011a4"
      issuer_address = create(:address)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        node_block.transactions.first.outputs_data[0] = "0x421d0000000000000000000000000000"
        node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt1_cell_type_hash,
                                                  args: issuer_address.lock_hash, hash_type: "type")
        create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: node_output.type.compute_hash,
                     block_timestamp: node_block.header.timestamp)
        local_block = node_data_processor.process_block(node_block)

        assert_equal ["udt"], local_block.cell_outputs.pluck(:cell_type).uniq
      end
    end

    test "#process_block should create udt account for the address when it receive udt cell for the first time" do
      issuer_address = create(:address)
      prepare_node_data(10)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        node_block.transactions.first.outputs_data[0] = "0x421d0000000000000000000000000000"
        node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                  args: issuer_address.lock_hash, hash_type: "type")
        create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: node_output.type.compute_hash,
                     block_timestamp: Time.current.to_i)
        address_hash = CkbUtils.generate_address(node_output.lock)
        address = Address.find_by_address_hash(address_hash)

        assert_difference -> { address.udt_accounts.count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should create udt account for the address when it receive m_nft_token cell for the first time" do
      create(:address)
      prepare_node_data(10)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        node_block.transactions.first.outputs_data[0] = "0x421d0000000000000000000000000000"
        node_output.type = CKB::Types::Script.new(code_hash: CkbSync::Api.instance.token_script_code_hash,
                                                  args: "0x3ae8bce37310b44b4dec3ce6b03308ba39b603de000000020000000c", hash_type: "type")
        create(:udt, code_hash: CkbSync::Api.instance.token_script_code_hash, type_hash: node_output.type.compute_hash,
                     block_timestamp: Time.current.to_i, udt_type: "m_nft_token")
        address_hash = CkbUtils.generate_address(node_output.lock)
        address = Address.find_by_address_hash(address_hash)

        assert_difference -> { address.udt_accounts.m_nft_token.count }, 1 do
          node_data_processor.process_block(node_block)
        end
        assert_equal 12, address.udt_accounts.m_nft_token.first.amount
      end
    end

    test "#process_block should destroy the udt account for the address when it consume the m_nft_token cell" do
      address = create(:address)
      block = create(:block, :with_block_hash)

      prepare_node_data(10)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        previous_ckb_transaction = create(:ckb_transaction, block: block)
        token_type_script = CKB::Types::Script.new(code_hash: CkbSync::Api.instance.token_script_code_hash,
                                                   args: "0x3ae8bce37310b44b4dec3ce6b03308ba39b603de000000020000000c", hash_type: "type")
        previous_cell_output = create(:cell_output, capacity: 1000 * 10**8, tx_hash: previous_ckb_transaction.tx_hash,
                                                    ckb_transaction: previous_ckb_transaction, block: block, cell_type: "m_nft_token", address: address, udt_amount: "12", cell_index: 0, data: "0x421d0000000000000000000000000000", type_hash: token_type_script.compute_hash)
        previous_cell_output_lock_script = create(:lock_script, code_hash: Settings.secp_cell_type_hash,
                                                                args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type")
        previous_cell_output_type_script = create(:type_script,
                                                  code_hash: CkbSync::Api.instance.token_script_code_hash, args: "0x3ae8bce37310b44b4dec3ce6b03308ba39b603de000000020000000c", hash_type: "type", cell_output: previous_cell_output)
        previous_cell_output.type_script_id = previous_cell_output_type_script.id
        previous_cell_output.lock_script_id = previous_cell_output_lock_script.id
        type_hash = CKB::Types::Script.new(**previous_cell_output_type_script.to_node).compute_hash
        udt = create(:udt, type_hash: type_hash, udt_type: "m_nft_token")
        address.udt_accounts.create(udt_type: "m_nft_token", type_hash: type_hash, udt: udt)
        input = CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: previous_cell_output.tx_hash,
                                                                                index: 0))
        output = CKB::Types::Output.new(capacity: 150 * 10**8,
                                        lock: CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, args: "0x3954acece65096bfa81258983ddb83915fc56bd8", hash_type: "type"), type: nil)
        tx = CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", inputs: [input], outputs: [output],
                                         outputs_data: ["0x"])
        node_block.transactions << tx

        assert_difference -> { address.udt_accounts.m_nft_token.count }, -1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should create one udt when there is one m_nft_token cell" do
      create(:address)
      prepare_node_data(10)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        node_block.transactions.first.outputs_data[0] = "0x421d0000000000000000000000000000"
        type = create(:type_script, code_hash: CkbSync::Api.instance.token_class_script_code_hash, hash_type: "type",
                                    args: "0x3ae8bce37310b44b4dec3ce6b03308ba39b603de00000002")
        create(:cell_output, :with_full_transaction_but_no_type_script, type_script_id: type.id,
                                                                        data: "0x00000003e800000000c000094669727374204e465400094669727374204e4654001768747470733a2f2f7878782e696d672e636f6d2f797979")
        node_output.type = CKB::Types::Script.new(code_hash: CkbSync::Api.instance.token_script_code_hash,
                                                  args: "0x3ae8bce37310b44b4dec3ce6b03308ba39b603de000000020000000c", hash_type: "type")
        assert_difference -> { Udt.m_nft_token.count }, 1 do
          node_data_processor.process_block(node_block)
        end
        udt = Udt.first
        assert_equal "First NFT", udt.full_name
        assert_equal "https://xxx.img.com/yyy", udt.icon_file
      end
    end

    test "#process_block should not create udt account for the address when it already received udt cell" do
      prepare_node_data(10)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                  args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3")
        create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: node_output.type.compute_hash)
        address_hash = CkbUtils.generate_address(node_output.lock)
        address = Address.find_by_address_hash(address_hash)
        create(:udt_account, code_hash: Settings.sudt_cell_type_hash, address: address,
                             type_hash: node_output.type.compute_hash)

        assert_difference -> { address.udt_accounts.count }, 0 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should update udt account for the address when it already received udt cell" do
      prepare_node_data(10)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                  args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type")
        create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: node_output.type.compute_hash)
        node_block.transactions.first.outputs_data[0] = "0x000050ad321ea12e0000000000000000"
        address_hash = CkbUtils.generate_address(node_output.lock)
        address = Address.find_by_address_hash(address_hash)
        create(:udt_account, code_hash: Settings.sudt_cell_type_hash, address: address,
                             type_hash: node_output.type.compute_hash)
        udt_account = address.udt_accounts.find_by(type_hash: node_output.type.compute_hash)

        assert_changes -> {
                         udt_account.reload.amount
                       }, from: udt_account.amount, to: CkbUtils.parse_udt_cell_data("0x000050ad321ea12e0000000000000000") do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should update multiple udt account for the address when it already received udt cell" do
      prepare_node_data(10)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        new_node_output = node_output.dup
        node_block.transactions.first.outputs << new_node_output
        new_node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                      args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac2", hash_type: "type")
        node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                  args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type")
        create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: node_output.type.compute_hash)
        create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: new_node_output.type.compute_hash)
        node_block.transactions.first.outputs_data[0] = "0x000050ad321ea12e0000000000000000"
        node_block.transactions.first.outputs_data[1] = "0x0000909dceda82370000000000000000"
        address_hash = CkbUtils.generate_address(node_output.lock)
        address = Address.find_by_address_hash(address_hash)
        create(:udt_account, code_hash: Settings.sudt_cell_type_hash, address: address,
                             type_hash: node_output.type.compute_hash)
        create(:udt_account, code_hash: Settings.sudt_cell_type_hash, address: address,
                             type_hash: new_node_output.type.compute_hash)
        udt_account = address.udt_accounts.find_by(type_hash: node_output.type.compute_hash)
        udt_account1 = address.udt_accounts.find_by(type_hash: new_node_output.type.compute_hash)

        node_data_processor.process_block(node_block)

        assert_equal CkbUtils.parse_udt_cell_data("0x000050ad321ea12e0000000000000000"), udt_account.reload.amount
        assert_equal CkbUtils.parse_udt_cell_data("0x0000909dceda82370000000000000000"), udt_account1.reload.amount
      end
    end

    test "#process_block should update udt addresses_count and total_amount when there are udt cells" do
      issuer_address1 = create(:address)
      issuer_address2 = create(:address)
      prepare_node_data(10)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        new_node_output = node_output.dup
        node_block.transactions.first.outputs << new_node_output
        new_node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                      args: issuer_address1.lock_hash, hash_type: "type")
        new_node_output.lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash,
                                                      args: issuer_address2.lock_hash)
        node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                  args: issuer_address1.lock_hash, hash_type: "type")
        udt = create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: node_output.type.compute_hash,
                           published: true, block_timestamp: node_block.header.timestamp)
        node_block.transactions.first.outputs_data[0] = "0x000050ad321ea12e0000000000000000"
        node_block.transactions.first.outputs_data[1] = "0x0000909dceda82370000000000000000"
        address_hash = CkbUtils.generate_address(node_output.lock)
        address = Address.find_by_address_hash(address_hash)
        create(:udt_account, code_hash: Settings.sudt_cell_type_hash, address: address,
                             type_hash: node_output.type.compute_hash, published: true)

        node_data_processor.process_block(node_block)

        expected_total_amount = CkbUtils.parse_udt_cell_data("0x000050ad321ea12e0000000000000000") + CkbUtils.parse_udt_cell_data("0x0000909dceda82370000000000000000")

        assert_equal expected_total_amount, udt.reload.total_amount
        assert_equal 2, udt.addresses_count
      end
    end

    test "#process_block should update multiple udt addresses_count and total_amount when there are multiple udt cells" do
      prepare_node_data(10)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        node_output = node_block.transactions.first.outputs.first
        new_node_output = node_output.dup
        node_block.transactions.first.outputs << new_node_output
        new_node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                      args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac2", hash_type: "type")
        node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                  args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type")
        udt1 = create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: node_output.type.compute_hash)
        udt2 = create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: new_node_output.type.compute_hash)
        node_block.transactions.first.outputs_data[0] = "0x000050ad321ea12e0000000000000000"
        node_block.transactions.first.outputs_data[1] = "0x0000909dceda82370000000000000000"
        address_hash = CkbUtils.generate_address(node_output.lock)
        address = Address.find_by_address_hash(address_hash)
        create(:udt_account, code_hash: Settings.sudt_cell_type_hash, address: address,
                             type_hash: node_output.type.compute_hash)
        create(:udt_account, code_hash: Settings.sudt_cell_type_hash, address: address,
                             type_hash: new_node_output.type.compute_hash)

        node_data_processor.process_block(node_block)

        assert_equal CkbUtils.parse_udt_cell_data("0x000050ad321ea12e0000000000000000"), udt1.reload.total_amount
        assert_equal 1, udt1.addresses_count
        assert_equal CkbUtils.parse_udt_cell_data("0x0000909dceda82370000000000000000"), udt2.reload.total_amount
        assert_equal 1, udt2.addresses_count
      end
    end

    test "should recalculate udt accounts when block is invalid" do
      issuer_address = create(:address)
      address = nil
      CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(22)
      VCR.use_cassette("blocks/21") do
        node_block = CkbSync::Api.instance.get_block_by_number(21)
        create(:block, :with_block_hash, number: node_block.header.number - 1, timestamp: 1557282351075)

        node_output = node_block.transactions.first.outputs.first
        node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                  args: issuer_address.lock_hash, hash_type: "type")
        node_block.transactions.first.outputs_data[0] = "0x000050ad321ea12e0000000000000000"
        create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: node_output.type.compute_hash,
                     block_timestamp: node_block.header.timestamp)
        node_data_processor.process_block(node_block)
        block = Block.find_by(number: 21)
        block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
        address_hash = CkbUtils.generate_address(node_output.lock)
        address = Address.find_by_address_hash(address_hash)
      end

      VCR.use_cassette("blocks/22") do
        assert_changes -> {
                         address.reload.udt_accounts.sum(:amount)
                       }, from: CkbUtils.parse_udt_cell_data("0x000050ad321ea12e0000000000000000"), to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should del m_nft_token udt accounts when block is invalid" do
      create(:address)
      address = nil
      CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(22)
      VCR.use_cassette("blocks/21") do
        node_block = CkbSync::Api.instance.get_block_by_number(21)
        create(:block, :with_block_hash, number: node_block.header.number - 1, timestamp: 1557282351075)

        node_output = node_block.transactions.first.outputs.first
        node_output.type = CKB::Types::Script.new(code_hash: CkbSync::Api.instance.token_script_code_hash,
                                                  args: "0x9cf6ef96c3f053f6d128903e608516d658cac2da0000000000000001", hash_type: "type")
        node_block.transactions.first.outputs_data[0] = "0x000050ad321ea12e0000000000000000"
        node_data_processor.process_block(node_block)
        block = Block.find_by(number: 21)
        block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
        address_hash = CkbUtils.generate_address(node_output.lock)
        address = Address.find_by_address_hash(address_hash)
      end

      VCR.use_cassette("blocks/22") do
        assert_difference -> { address.reload.udt_accounts.m_nft_token.count }, -1 do
          node_data_processor.call
        end
      end
    end

    test "should recalculate multiple udt accounts when block is invalid" do
      issuer_address1 = create(:address)
      issuer_address2 = create(:address)
      address = nil
      CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(22)
      VCR.use_cassette("blocks/21") do
        node_block = CkbSync::Api.instance.get_block_by_number(21)
        create(:block, :with_block_hash, number: node_block.header.number - 1, timestamp: 1557282351075)

        node_output = node_block.transactions.first.outputs.first
        new_node_output = node_output.dup
        node_block.transactions.first.outputs << new_node_output
        new_node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                      args: issuer_address1.lock_hash, hash_type: "type")
        node_output.type = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash,
                                                  args: issuer_address2.lock_hash, hash_type: "type")
        node_block.transactions.first.outputs_data[0] = "0x000050ad321ea12e0000000000000000"
        node_block.transactions.first.outputs_data[1] = "0x0000909dceda82370000000000000000"
        create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: node_output.type.compute_hash,
                     block_timestamp: node_block.header.timestamp)
        create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: new_node_output.type.compute_hash,
                     block_timestamp: node_block.header.timestamp)
        node_data_processor.process_block(node_block)
        block = Block.find_by(number: 21)
        block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
        address_hash = CkbUtils.generate_address(node_output.lock)
        address = Address.find_by_address_hash(address_hash)
      end

      VCR.use_cassette("blocks/22") do
        old_total_amount = CkbUtils.parse_udt_cell_data("0x000050ad321ea12e0000000000000000") + CkbUtils.parse_udt_cell_data("0x0000909dceda82370000000000000000")
        assert_changes -> { address.reload.udt_accounts.sum(:amount) }, from: old_total_amount, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should update udt account both input and output" do
      issuer_address = create(:address)
      udt_type_script = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, args: issuer_address.lock_hash,
                                               hash_type: "type")
      create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: udt_type_script.compute_hash)
      block = create(:block, :with_block_hash)
      previous_cell_output_lock_script = create(:lock_script, code_hash: Settings.secp_cell_type_hash,
                                                              args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type")
      address = previous_cell_output_lock_script.address
      udt_lock_script = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash,
                                               args: "0x3954acece65096bfa81258983ddb83915fc56bd8", hash_type: "type")
      udt_amount = 1000000
      create(:udt_account, address: address, amount: udt_amount, type_hash: udt_type_script.compute_hash)
      previous_ckb_transaction = create(:ckb_transaction, address: address)
      previous_cell_output = create(:cell_output,
                                    ckb_transaction: previous_ckb_transaction,
                                    block: block,
                                    cell_type: "udt",
                                    address: address,
                                    udt_amount: udt_amount,
                                    cell_index: 0,
                                    tx_hash: previous_ckb_transaction.tx_hash,
                                    capacity: 300 * 10**8,
                                    type_hash: udt_type_script.compute_hash)
      previous_cell_output_type_script = create(:type_script, code_hash: Settings.sudt_cell_type_hash,
                                                              args: issuer_address.lock_hash, hash_type: "data", cell_output: previous_cell_output)
      previous_cell_output.type_script_id = previous_cell_output_type_script.id
      previous_cell_output.lock_script_id = previous_cell_output_lock_script.id

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        input = CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: previous_cell_output.tx_hash,
                                                                                index: 0))
        output = CKB::Types::Output.new(capacity: 150 * 10**8, lock: udt_lock_script, type: udt_type_script)
        tx = CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", inputs: [input], outputs: [output],
                                         outputs_data: ["0x000050ad321ea12e0000000000000000"])
        node_block.transactions << tx
        output_address_hash = CkbUtils.generate_address(output.lock)
        create(:address, address_hash: output_address_hash)
        output_address = Address.find_by_address_hash(output_address_hash)
        create(:udt_account, code_hash: Settings.sudt_cell_type_hash, address: output_address,
                             type_hash: udt_type_script.compute_hash, amount: 0)
        udt_account = output_address.udt_accounts.find_by(type_hash: output.type.compute_hash)
        assert_changes -> {
                         udt_account.reload.amount
                       }, from: 0, to: CkbUtils.parse_udt_cell_data("0x000050ad321ea12e0000000000000000") do
          node_data_processor.process_block(node_block)
        end

        assert_equal 0, address.udt_accounts.find_by(type_hash: udt_type_script.compute_hash).amount
        assert_equal 0, address.reload.balance_occupied
        assert_equal 150 * 10**8, output_address.reload.balance_occupied
      end
    end

    test "should update tx's contained address ids" do
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
      lock = create(:lock_script)
      create(:cell_output, ckb_transaction: tx1,  block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx2,  block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx3,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx4,  block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx5,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5, lock_script_id: lock.id)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      outputs1 = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %w[0x 0x 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs1, outputs_data: %w[0x 0x 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)

      address1 = Address.find_by(lock_hash: lock1.compute_hash)
      address2 = Address.find_by(lock_hash: lock2.compute_hash)
      address3 = Address.find_by(lock_hash: lock3.compute_hash)
      tx = block.ckb_transactions.where(is_cellbase: false).first
      tx1 = block.ckb_transactions.where(is_cellbase: false).second
      assert_equal [address1.id, address2.id, address3.id, input_address1.id, input_address2.id, input_address3.id].sort,
                   tx.contained_address_ids.sort
      assert_equal [address1.id, address2.id, address3.id, input_address4.id, input_address5.id].sort,
                   tx1.contained_address_ids.sort
    end

    test "should update tx's tags when output have nervos_dao_deposit cells" do
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
      create(:cell_output, ckb_transaction: tx1,  block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1)
      create(:cell_output, ckb_transaction: tx2,  block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2)
      create(:cell_output, ckb_transaction: tx3,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3)
      create(:cell_output, ckb_transaction: tx4,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4)
      create(:cell_output, ckb_transaction: tx5, block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      dao_type = CKB::Types::Script.new(code_hash: Settings.dao_type_hash, hash_type: "type", args: "0x")
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      outputs1 = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %w[0x0000000000000000 0x0000000000000000 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs1, outputs_data: %w[0x0000000000000000 0x0000000000000000 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)

      tx = block.ckb_transactions.where(is_cellbase: false).first
      tx1 = block.ckb_transactions.where(is_cellbase: false).second

      assert_equal ["dao"], tx.tags
      assert_equal ["dao"], tx1.tags
      assert_equal 2, DaoContract.default_contract.ckb_transactions_count
    end

    test "should recalculate dao contract ckb_transactions_count when block is invalid and has dao txs" do
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      tx4 = create(:ckb_transaction, block: block2)
      tx5 = create(:ckb_transaction, block: block2)
      input_address1 = create(:address, balance: 50000 * 10**8)
      input_address2 = create(:address, balance: 60000 * 10**8)
      input_address3 = create(:address, balance: 70000 * 10**8)
      input_address4 = create(:address, balance: 70000 * 10**8)
      input_address5 = create(:address, balance: 70000 * 10**8)
      create(:cell_output, ckb_transaction: tx1,  block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1)
      create(:cell_output, ckb_transaction: tx2,  block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2)
      create(:cell_output, ckb_transaction: tx3,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3)
      create(:cell_output, ckb_transaction: tx4,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4)
      create(:cell_output, ckb_transaction: tx5,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      dao_type = CKB::Types::Script.new(code_hash: Settings.dao_type_hash, hash_type: "type", args: "0x")
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      outputs1 = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %w[0x0000000000000000 0x0000000000000000 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs1, outputs_data: %w[0x0000000000000000 0x0000000000000000 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)
      CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(block.number + 1)

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        assert_changes -> { DaoContract.default_contract.ckb_transactions_count }, from: 2, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should update tx's tags when output have udt cells" do
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      input_address1 = create(:address)
      input_address2 = create(:address)
      input_address3 = create(:address)
      lock = create(:lock_script)
      create(:cell_output, ckb_transaction: tx1,  block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx2,  block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx3,  block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3, lock_script_id: lock.id)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      udt_script = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script.args, address_hash: "0x#{SecureRandom.hex(32)}")
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: udt_script),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: udt_script),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %W[#{CKB::Utils.generate_sudt_amount(1000)} #{CKB::Utils.generate_sudt_amount(1000)} 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)

      tx = block.ckb_transactions.where(is_cellbase: false).first

      assert_equal ["udt"], tx.tags
    end

    test "should update tx's tags when output have udt cells and nervos_dao_deposit cell" do
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      input_address1 = create(:address)
      input_address2 = create(:address)
      input_address3 = create(:address)
      lock = create(:lock_script)
      create(:cell_output, ckb_transaction: tx1, block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx2, block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx3, block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3, lock_script_id: lock.id)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      dao_type = CKB::Types::Script.new(code_hash: Settings.dao_type_hash, hash_type: "type", args: "0x")
      udt_script = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script.args, address_hash: "0x#{SecureRandom.hex(32)}")
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3, type: udt_script)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %W[0x0000000000000000 0x0000000000000000 #{CKB::Utils.generate_sudt_amount(1000)}], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)

      tx = block.ckb_transactions.where(is_cellbase: false).first

      assert_equal %w[dao udt], tx.tags
      assert_equal 1, DaoContract.default_contract.ckb_transactions_count
    end

    test "should update tx's tags when input have udt cells" do
      DaoContract.default_contract.update(total_deposit: 100000000000000)
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      tx4 = create(:ckb_transaction, block: block2)
      tx5 = create(:ckb_transaction, block: block2)

      lock1 = create(:lock_script, args: "0x#{SecureRandom.hex(20)}", code_hash: Settings.secp_cell_type_hash,
                                   hash_type: "type")
      lock2 = create(:lock_script, args: "0x#{SecureRandom.hex(20)}", code_hash: Settings.secp_cell_type_hash,
                                   hash_type: "type")
      lock3 = create(:lock_script, args: "0x#{SecureRandom.hex(20)}", code_hash: Settings.secp_cell_type_hash,
                                   hash_type: "type")
      lock4 = create(:lock_script, args: "0x#{SecureRandom.hex(20)}", code_hash: Settings.secp_cell_type_hash,
                                   hash_type: "type")
      lock5 = create(:lock_script, args: "0x#{SecureRandom.hex(20)}", code_hash: Settings.secp_cell_type_hash,
                                   hash_type: "type")
      input_address1 = create(:address, lock_script_id: lock1.id)
      input_address2 = create(:address, lock_script_id: lock2.id)
      input_address3 = create(:address, lock_script_id: lock3.id)
      input_address4 = create(:address, lock_script_id: lock4.id)
      input_address5 = create(:address, lock_script_id: lock5.id)
      udt_script = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(32)}")
      udt_script1 = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                           args: "0x#{SecureRandom.hex(32)}")
      create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: udt_script.compute_hash)
      create(:udt, code_hash: Settings.sudt_cell_type_hash, type_hash: udt_script1.compute_hash)

      output1 = create(:cell_output, ckb_transaction: tx1,  block: block1, capacity: 50000 * 10**8,
                                     tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, cell_type: "udt", lock_script_id: lock1.id, type_hash: udt_script.compute_hash)
      output2 = create(:cell_output, ckb_transaction: tx2, block: block2, capacity: 60000 * 10**8,
                                     tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, cell_type: "udt", lock_script_id: lock2.id, type_hash: udt_script.compute_hash)
      output3 = create(:cell_output, ckb_transaction: tx3, block: block2, capacity: 70000 * 10**8,
                                     tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3, cell_type: "udt", lock_script_id: lock3.id, type_hash: udt_script.compute_hash)
      output4 = create(:cell_output, ckb_transaction: tx4, block: block2, capacity: 70000 * 10**8,
                                     tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4, cell_type: "udt", lock_script_id: lock4.id, type_hash: udt_script.compute_hash)
      output5 = create(:cell_output, ckb_transaction: tx5, block: block2, capacity: 70000 * 10**8,
                                     tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5, cell_type: "udt", lock_script_id: lock5.id, type_hash: udt_script.compute_hash)

      create(:type_script, args: udt_script.args, code_hash: Settings.sudt_cell_type_hash, hash_type: "data",
                           cell_output: output1)
      create(:type_script, args: udt_script.args, code_hash: Settings.sudt_cell_type_hash, hash_type: "data",
                           cell_output: output2)
      create(:type_script, args: udt_script.args, code_hash: Settings.sudt_cell_type_hash, hash_type: "data",
                           cell_output: output3)
      create(:type_script, args: udt_script1.args, code_hash: Settings.sudt_cell_type_hash, hash_type: "data",
                           cell_output: output4)
      create(:type_script, args: udt_script1.args, code_hash: Settings.sudt_cell_type_hash, hash_type: "data",
                           cell_output: output5)
      Address.create(lock_hash: udt_script.args, address_hash: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script1.args, address_hash: "0x#{SecureRandom.hex(32)}")

      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")

      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]

      outputs1 = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %w[0x 0x 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs1, outputs_data: %w[0x 0x 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)

      tx = block.ckb_transactions.where(is_cellbase: false).first
      tx1 = block.ckb_transactions.where(is_cellbase: false).second

      assert_equal ["udt"], tx.tags
      assert_equal ["udt"], tx1.tags
    end

    test "should update tx's tags when input have udt cells and nervos_dao_withdrawing cells" do
      DaoContract.default_contract.update(total_deposit: 100000000000000)
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      deposit_block = create(:block, :with_block_hash,
                             number: DEFAULT_NODE_BLOCK_NUMBER - 5,
                             dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100")
      deposit_tx = create(:ckb_transaction, block: deposit_block)
      deposit_block1 = create(:block, :with_block_hash,
                              number: DEFAULT_NODE_BLOCK_NUMBER - 6,
                              dao: "0x185369bb078607007224be7987882300517774e04400000000e3bad4847a0100")
      deposit_tx1 = create(:ckb_transaction, block: deposit_block1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      tx4 = create(:ckb_transaction, block: block2)
      tx5 = create(:ckb_transaction, block: block2)

      lock1 = create(:lock_script, args: "0x#{SecureRandom.hex(20)}",
                                   code_hash: Settings.secp_cell_type_hash,
                                   hash_type: "type")
      lock2 = create(:lock_script, args: "0x#{SecureRandom.hex(20)}",
                                   code_hash: Settings.secp_cell_type_hash,
                                   hash_type: "type")
      lock3 = create(:lock_script, args: "0x#{SecureRandom.hex(20)}",
                                   code_hash: Settings.secp_cell_type_hash,
                                   hash_type: "type")
      lock4 = create(:lock_script, args: "0x#{SecureRandom.hex(20)}",
                                   code_hash: Settings.secp_cell_type_hash,
                                   hash_type: "type")
      lock5 = create(:lock_script, args: "0x#{SecureRandom.hex(20)}",
                                   code_hash: Settings.secp_cell_type_hash,
                                   hash_type: "type")
      input_address1 = create(:address, lock_script_id: lock1.id)
      input_address2 = create(:address, lock_script_id: lock2.id)
      input_address3 = create(:address, lock_script_id: lock3.id)
      input_address4 = create(:address, lock_script_id: lock4.id)
      input_address5 = create(:address, lock_script_id: lock5.id)
      udt_script = CKB::Types::Script.new(
        code_hash: Settings.sudt_cell_type_hash,
        hash_type: "type",
        args: "0x#{SecureRandom.hex(32)}"
      )
      udt_script1 = CKB::Types::Script.new(
        code_hash: Settings.sudt_cell_type_hash,
        hash_type: "type",
        args: "0x#{SecureRandom.hex(32)}"
      )
      create(:udt, code_hash: Settings.sudt_cell_type_hash,
                   type_hash: udt_script.compute_hash)
      create(:udt, code_hash: Settings.sudt_cell_type_hash,
                   type_hash: udt_script1.compute_hash)

      # nervos_dao_deposit cells belongs to input_address1
      create(:cell_output, ckb_transaction: deposit_tx,
                           block: deposit_block,
                           capacity: 50000 * 10**8,
                           occupied_capacity: 61 * 10**8,
                           tx_hash: deposit_tx.tx_hash,
                           cell_index: 0,
                           address: input_address1,
                           cell_type: "nervos_dao_deposit",
                           dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100", lock_script_id: lock1.id)
      create(:cell_output, ckb_transaction: deposit_tx,
                           block: deposit_block,
                           capacity: 40000 * 10**8,
                           occupied_capacity: 61 * 10**8,
                           tx_hash: deposit_tx.tx_hash,
                           cell_index: 1,
                           address: input_address1,
                           cell_type: "nervos_dao_deposit",
                           dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100", lock_script_id: lock1.id)
      create(:cell_output, ckb_transaction: deposit_tx,
                           block: deposit_block,
                           capacity: 40000 * 10**8,
                           occupied_capacity: 61 * 10**8,
                           tx_hash: deposit_tx.tx_hash,
                           cell_index: 2,
                           address: input_address1,
                           cell_type: "nervos_dao_deposit",
                           dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100", lock_script_id: lock1.id)

      # nervos_dao_withdrawing inputs
      create(:cell_input, ckb_transaction: tx1,
                          block: block1,
                          previous_output: {
                            tx_hash: deposit_tx.tx_hash,
                            index: 0
                          })
      create(:cell_input, ckb_transaction: tx2,
                          block: block2,
                          previous_output: {
                            tx_hash: deposit_tx.tx_hash,
                            index: 1
                          })
      create(:cell_input, ckb_transaction: tx2,
                          block: block2,
                          previous_output: {
                            tx_hash: deposit_tx.tx_hash,
                            index: 2
                          })

      # nervos_dao_withdrawing cells
      create(:cell_output, ckb_transaction: tx1,
                           block: block1,
                           capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash,
                           cell_index: 0,
                           address: input_address1,
                           cell_type: "nervos_dao_withdrawing",
                           dao: "0x28ef3c7ff3860700d88b1a61958923008ae424cd7200000000e3bad4847a0100", lock_script_id: lock1.id, occupied_capacity: 61 * 10**8)
      create(:cell_output, ckb_transaction: tx2,
                           block: block2,
                           capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash,
                           cell_index: 1,
                           address: input_address2,
                           cell_type: "nervos_dao_withdrawing",
                           dao: "0x2cd631702e870700b3df08d7d889230036f787487e00000000e3bad4847a0100", lock_script_id: lock2.id, occupied_capacity: 61 * 10**8)

      # udt cell
      create(:cell_output, ckb_transaction: tx3,
                           block: block2,
                           capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash,
                           cell_index: 2,
                           address: input_address3,
                           cell_type: "udt",
                           lock_script_id: lock3.id,
                           type_hash: udt_script.compute_hash)

      # nervos_dao_deposit cells
      create(:cell_output, ckb_transaction: deposit_tx1,
                           block: deposit_block1,
                           capacity: 50000 * 10**8,
                           occupied_capacity: 61 * 10**8,
                           tx_hash: deposit_tx1.tx_hash,
                           cell_index: 0,
                           address: input_address4,
                           cell_type: "nervos_dao_deposit",
                           dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100", lock_script_id: lock4.id)
      create(:cell_output, ckb_transaction: deposit_tx1,
                           block: deposit_block1,
                           capacity: 40000 * 10**8,
                           occupied_capacity: 61 * 10**8,
                           tx_hash: deposit_tx1.tx_hash,
                           cell_index: 1,
                           address: input_address5,
                           cell_type: "nervos_dao_deposit",
                           dao: "0x1c3a5eac4286070025e0edf5ca8823001c957f5b5000000000e3bad4847a0100", lock_script_id: lock5.id)

      # nervos_dao_withdrawing inputs
      create(:cell_input, ckb_transaction: tx4,
                          block: block2,
                          previous_output: {
                            tx_hash: deposit_tx1.tx_hash,
                            index: 0
                          })
      create(:cell_input, ckb_transaction: tx5,
                          block: block2,
                          previous_output: {
                            tx_hash: deposit_tx1.tx_hash,
                            index: 1
                          })
      # nervos_dao_withdrawing cell
      create(:cell_output, ckb_transaction: tx4,
                           block: block1,
                           capacity: 100000 * 10**8,
                           tx_hash: tx4.tx_hash,
                           cell_index: 0,
                           address: input_address4,
                           cell_type: "nervos_dao_withdrawing",
                           dao: "0x28ef3c7ff3860700d88b1a61958923008ae424cd7200000000e3bad4847a0100", lock_script_id: lock4.id, occupied_capacity: 61 * 10**8)

      # udt cell
      create(:cell_output, ckb_transaction: tx5,
                           block: block2,
                           capacity: 60000 * 10**8,
                           tx_hash: tx5.tx_hash,
                           cell_index: 0,
                           address: input_address5,
                           cell_type: "udt",
                           lock_script_id: lock5.id,
                           type_hash: udt_script.compute_hash)

      create(:type_script, args: udt_script.args,
                           code_hash: Settings.sudt_cell_type_hash,
                           hash_type: "data")
      create(:type_script, args: udt_script.args,
                           code_hash: Settings.sudt_cell_type_hash,
                           hash_type: "data")
      create(:type_script, args: udt_script.args,
                           code_hash: Settings.sudt_cell_type_hash,
                           hash_type: "data")
      create(:type_script, args: udt_script1.args,
                           code_hash: Settings.sudt_cell_type_hash,
                           hash_type: "data")
      create(:type_script, args: udt_script1.args,
                           code_hash: Settings.sudt_cell_type_hash,
                           hash_type: "data")
      Address.create(lock_hash: udt_script.args, address_hash: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script1.args, address_hash: "0x#{SecureRandom.hex(32)}")

      header = CKB::Types::BlockHeader.new(
        compact_target: "0x1000",
        hash: "0x#{SecureRandom.hex(32)}",
        number: DEFAULT_NODE_BLOCK_NUMBER,
        parent_hash: "0x#{SecureRandom.hex(32)}",
        nonce: 1757392074788233522,
        timestamp: CkbUtils.time_in_milliseconds(Time.current),
        transactions_root: "0x#{SecureRandom.hex(32)}",
        proposals_hash: "0x#{SecureRandom.hex(32)}",
        extra_hash: "0x#{SecureRandom.hex(32)}",
        version: 0,
        epoch: 1,
        dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000"
      )
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)), # nervos_dao_withdrawing cell
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)), # nervos_dao_withdrawing cell
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))  # udt cell
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)), # nervos_dao_withdrawing cell
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))  # udt cell
      ]
      lock1 = CKB::Types::Script.new(
        code_hash: Settings.secp_cell_type_hash,
        hash_type: "type",
        args: "0x#{SecureRandom.hex(20)}"
      )
      lock2 = CKB::Types::Script.new(
        code_hash: Settings.secp_cell_type_hash,
        hash_type: "type",
        args: "0x#{SecureRandom.hex(20)}"
      )
      lock3 = CKB::Types::Script.new(
        code_hash: Settings.secp_cell_type_hash,
        hash_type: "type",
        args: "0x#{SecureRandom.hex(20)}"
      )

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
      miner_lock = CKB::Types::Script.new(
        code_hash: Settings.secp_cell_type_hash,
        hash_type: "type",
        args: "0x#{SecureRandom.hex(20)}"
      )
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(
          hash: "0x#{SecureRandom.hex(32)}",
          cell_deps: [],
          header_deps: [],
          inputs: cellbase_inputs,
          outputs: cellbase_outputs,
          outputs_data: %w[0x],
          witnesses: [
            "0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"
          ]
        ),
        CKB::Types::Transaction.new(
          hash: "0x#{SecureRandom.hex(32)}",
          cell_deps: [],
          header_deps: [block1.block_hash],
          inputs: inputs,
          outputs: outputs,
          outputs_data: %w[0x 0x 0x],
          witnesses: [
            "0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"
          ]
        ),
        CKB::Types::Transaction.new(
          hash: "0x#{SecureRandom.hex(32)}",
          cell_deps: [],
          header_deps: [block1.block_hash],
          inputs: inputs1,
          outputs: outputs1,
          outputs_data: %w[0x 0x 0x],
          witnesses: [
            "0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"
          ]
        )
      ]
      node_block = CKB::Types::Block.new(
        uncles: [],
        proposals: [],
        transactions: transactions,
        header: header
      )

      block = node_data_processor.process_block(node_block)

      tx = block.ckb_transactions.where(is_cellbase: false).first
      tx1 = block.ckb_transactions.where(is_cellbase: false).second

      assert_equal %w[dao udt], tx.tags
      assert_equal %w[dao udt], tx1.tags

      assert_equal 2, DaoContract.default_contract.ckb_transactions_count
    end

    test "#process_block should not update tx's tags when there aren't dao cells and udt cells" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        block = node_data_processor.process_block(node_block)
        tags = block.ckb_transactions.pluck(:tags).flatten

        assert_empty tags
      end
    end

    test "#process_block should not update tx's contained_udt_ids when there aren't udt cells" do
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
        node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
        create(:block, :with_block_hash, number: node_block.header.number - 1)
        block = node_data_processor.process_block(node_block)
        contained_udt_ids = UdtTransaction.where(ckb_transaction_id: block.ckb_transactions.pluck(:id)).pluck(:udt_id)

        assert_empty contained_udt_ids
      end
    end

    test "#process_block should update tx's contained_udt_ids when there are udt cells in outputs" do
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
      lock = create(:lock_script)
      create(:cell_output, ckb_transaction: tx1, block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx2, block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx3, block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx4, block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx5, block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5, lock_script_id: lock.id)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      udt_script1 = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                           args: "0x#{SecureRandom.hex(32)}")
      udt_script2 = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                           args: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script1.args, address_hash: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script2.args, address_hash: "0x#{SecureRandom.hex(32)}")
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: udt_script1),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: udt_script2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      outputs1 = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: udt_script1),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: udt_script2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: udt_script2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %W[#{CKB::Utils.generate_sudt_amount(1000)} #{CKB::Utils.generate_sudt_amount(1000)} 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs1, outputs_data: %W[#{CKB::Utils.generate_sudt_amount(1000)} #{CKB::Utils.generate_sudt_amount(1000)} #{CKB::Utils.generate_sudt_amount(1000)} 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)
      udt1 = Udt.find_by(args: udt_script1.args)
      udt2 = Udt.find_by(args: udt_script2.args)
      tx = block.ckb_transactions.where(is_cellbase: false).first
      tx1 = block.ckb_transactions.where(is_cellbase: false).second

      assert_equal [udt1.id, udt2.id], tx.contained_udt_ids.sort
      assert_equal [udt1.id, udt2.id], tx1.contained_udt_ids
      assert_equal 2, udt1.ckb_transactions_count
      assert_equal 2, udt2.ckb_transactions_count
    end

    test "#process_block should update tx's contained_udt_ids when there are udt cells in inputs" do
      udt_script1 = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                           args: "0x#{SecureRandom.hex(32)}")
      udt_script2 = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                           args: "0x#{SecureRandom.hex(32)}")
      type_script1 = create(:type_script, args: udt_script1.args, code_hash: Settings.sudt_cell_type_hash,
                                          hash_type: "data")
      type_script2 = create(:type_script, args: udt_script2.args, code_hash: Settings.sudt_cell_type_hash,
                                          hash_type: "data")
      udt1 = create(:udt, type_hash: CKB::Types::Script.new(**type_script1.to_node).compute_hash,
                          args: udt_script1.args, ckb_transactions_count: 3)
      udt2 = create(:udt, type_hash: CKB::Types::Script.new(**type_script2.to_node).compute_hash,
                          args: udt_script2.args, ckb_transactions_count: 2)
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1, contained_udt_ids: [udt1.id])
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2, contained_udt_ids: [udt2.id])
      tx3 = create(:ckb_transaction, block: block2, contained_udt_ids: [udt1.id])
      tx4 = create(:ckb_transaction, block: block2, contained_udt_ids: [udt1.id])
      tx5 = create(:ckb_transaction, block: block2, contained_udt_ids: [udt2.id])
      input_address1 = create(:address)
      input_address2 = create(:address)
      input_address3 = create(:address)
      input_address4 = create(:address)
      input_address5 = create(:address)

      address1_lock = create(:lock_script, address: input_address1, args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash, hash_type: "type")
      address2_lock = create(:lock_script, address: input_address2, args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash, hash_type: "type")
      address3_lock = create(:lock_script, address: input_address3, args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash, hash_type: "type")
      address4_lock = create(:lock_script, address: input_address3, args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash, hash_type: "type")
      address5_lock = create(:lock_script, address: input_address3, args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash, hash_type: "type")
      output1 = create(:cell_output, ckb_transaction: tx1, block: block1, capacity: 50000 * 10**8,
                                     tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, cell_type: "udt", lock_script_id: address1_lock.id, type_script_id: type_script1.id, type_hash: udt_script1.compute_hash)
      output2 = create(:cell_output, ckb_transaction: tx2, block: block2, capacity: 60000 * 10**8,
                                     tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, cell_type: "udt", lock_script_id: address2_lock.id, type_script_id: type_script2.id, type_hash: udt_script2.compute_hash)
      output3 = create(:cell_output, ckb_transaction: tx3, block: block2, capacity: 70000 * 10**8,
                                     tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3, cell_type: "udt", lock_script_id: address3_lock.id, type_script_id: type_script1.id, type_hash: udt_script1.compute_hash)
      output4 = create(:cell_output, ckb_transaction: tx4, block: block2, capacity: 70000 * 10**8,
                                     tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4, cell_type: "udt", lock_script_id: address4_lock.id, type_script_id: type_script1.id, type_hash: udt_script1.compute_hash)
      output5 = create(:cell_output, ckb_transaction: tx5, block: block2, capacity: 70000 * 10**8,
                                     tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5, cell_type: "udt", lock_script_id: address5_lock.id, type_script_id: type_script2.id, type_hash: udt_script2.compute_hash)
      create(:type_script, args: udt_script1.args, code_hash: Settings.sudt_cell_type_hash, hash_type: "data",
                           cell_output: output1)
      create(:type_script, args: udt_script1.args, code_hash: Settings.sudt_cell_type_hash, hash_type: "data",
                           cell_output: output2)
      create(:type_script, args: udt_script2.args, code_hash: Settings.sudt_cell_type_hash, hash_type: "data",
                           cell_output: output3)
      output1.update(type_hash: CKB::Types::Script.new(**output1.type_script.to_node).compute_hash)
      output2.update(type_hash: CKB::Types::Script.new(**output2.type_script.to_node).compute_hash)
      output3.update(type_hash: CKB::Types::Script.new(**output3.type_script.to_node).compute_hash)
      output4.update(type_hash: CKB::Types::Script.new(**output4.type_script.to_node).compute_hash)
      output5.update(type_hash: CKB::Types::Script.new(**output5.type_script.to_node).compute_hash)
      Address.create(lock_hash: udt_script1.args, address_hash: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script2.args, address_hash: "0x#{SecureRandom.hex(32)}")

      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")

      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %w[0x 0x 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs, outputs_data: %w[0x 0x 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)
      udt1 = Udt.find_by(args: udt_script1.args)
      udt2 = Udt.find_by(args: udt_script2.args)

      tx = block.ckb_transactions.where(is_cellbase: false).first
      tx1 = block.ckb_transactions.where(is_cellbase: false).second

      assert_equal [udt1.id, udt2.id], tx.contained_udt_ids
      assert_equal [udt1.id, udt2.id], tx1.contained_udt_ids
      assert_equal 5, udt1.ckb_transactions_count
      assert_equal 4, udt2.ckb_transactions_count
    end

    test "should recalculate udts ckb transactions count when block is invalid and outputs has udt cell" do
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      tx4 = create(:ckb_transaction, block: block2)
      tx5 = create(:ckb_transaction, block: block2)
      input_address1 = create(:address, balance: 50000 * 10**8)
      input_address2 = create(:address, balance: 60000 * 10**8)
      input_address3 = create(:address, balance: 70000 * 10**8)
      input_address4 = create(:address, balance: 70000 * 10**8)
      input_address5 = create(:address, balance: 70000 * 10**8)
      create(:cell_output, ckb_transaction: tx1, block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1)
      create(:cell_output, ckb_transaction: tx2, block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2)
      create(:cell_output, ckb_transaction: tx3, block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3)
      create(:cell_output, ckb_transaction: tx4, block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4)
      create(:cell_output, ckb_transaction: tx5, block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      udt_script1 = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                           args: "0x#{SecureRandom.hex(32)}")
      udt_script2 = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                           args: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script1.args, address_hash: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script2.args, address_hash: "0x#{SecureRandom.hex(32)}")
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: udt_script1),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: udt_script2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      outputs1 = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: udt_script1),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: udt_script2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: udt_script2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %W[#{CKB::Utils.generate_sudt_amount(1000)} #{CKB::Utils.generate_sudt_amount(1000)} 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs1, outputs_data: %W[#{CKB::Utils.generate_sudt_amount(1000)} #{CKB::Utils.generate_sudt_amount(1000)} #{CKB::Utils.generate_sudt_amount(1000)} 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)
      CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(block.number + 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_data_processor.call
      end

      udt1 = Udt.find_by(args: udt_script1.args)
      udt2 = Udt.find_by(args: udt_script2.args)

      assert_equal 0, udt1.reload.ckb_transactions_count
      assert_equal 0, udt2.reload.ckb_transactions_count
    end

    test "should recalculate udts ckb transactions count when block is invalid and inputs has udt cell" do
      udt_script1 = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                           args: "0x#{SecureRandom.hex(32)}")
      udt_script2 = CKB::Types::Script.new(code_hash: Settings.sudt_cell_type_hash, hash_type: "type",
                                           args: "0x#{SecureRandom.hex(32)}")
      type_script1 = create(:type_script, args: udt_script1.args, code_hash: Settings.sudt_cell_type_hash,
                                          hash_type: "data")
      type_script2 = create(:type_script, args: udt_script2.args, code_hash: Settings.sudt_cell_type_hash,
                                          hash_type: "data")
      type_script3 = create(:type_script, args: udt_script1.args, code_hash: Settings.sudt_cell_type_hash,
                                          hash_type: "data")
      type_script4 = create(:type_script, args: udt_script1.args, code_hash: Settings.sudt_cell_type_hash,
                                          hash_type: "data")
      type_script5 = create(:type_script, args: udt_script2.args, code_hash: Settings.sudt_cell_type_hash,
                                          hash_type: "data")
      udt1 = create(:udt, type_hash: CKB::Types::Script.new(**type_script1.to_node).compute_hash,
                          args: udt_script1.args, ckb_transactions_count: 3)
      udt2 = create(:udt, type_hash: CKB::Types::Script.new(**type_script2.to_node).compute_hash,
                          args: udt_script2.args, ckb_transactions_count: 2)
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1, contained_udt_ids: [udt1.id])
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2, contained_udt_ids: [udt2.id])
      tx3 = create(:ckb_transaction, block: block2, contained_udt_ids: [udt1.id])
      tx4 = create(:ckb_transaction, block: block2, contained_udt_ids: [udt1.id])
      tx5 = create(:ckb_transaction, block: block2, contained_udt_ids: [udt2.id])
      input_address1 = create(:address, balance: 50000 * 10**8)
      input_address2 = create(:address, balance: 60000 * 10**8)
      input_address3 = create(:address, balance: 70000 * 10**8)
      input_address4 = create(:address, balance: 70000 * 10**8)
      input_address5 = create(:address, balance: 70000 * 10**8)
      address1_lock = create(:lock_script, address_id: input_address1.id, args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash, hash_type: "type")
      address2_lock = create(:lock_script, address_id: input_address2.id, args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash, hash_type: "type")
      address3_lock = create(:lock_script, address_id: input_address3.id, args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash, hash_type: "type")
      address4_lock = create(:lock_script, address_id: input_address4.id, args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash, hash_type: "type")
      address5_lock = create(:lock_script, address_id: input_address5.id, args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash, hash_type: "type")

      output1 = create(:cell_output, ckb_transaction: tx1, block: block1, capacity: 50000 * 10**8,
                                     tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, cell_type: "udt", lock_script_id: address1_lock.id, type_script_id: type_script1.id)
      output2 = create(:cell_output, ckb_transaction: tx2, block: block2, capacity: 60000 * 10**8,
                                     tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, cell_type: "udt", lock_script_id: address2_lock.id, type_script_id: type_script2.id)
      output3 = create(:cell_output, ckb_transaction: tx3, block: block2, capacity: 70000 * 10**8,
                                     tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3, cell_type: "udt", lock_script_id: address3_lock.id, type_script_id: type_script3.id)
      output4 = create(:cell_output, ckb_transaction: tx4, block: block2, capacity: 70000 * 10**8,
                                     tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4, cell_type: "udt", lock_script_id: address4_lock.id, type_script_id: type_script4.id)
      output5 = create(:cell_output, ckb_transaction: tx5, block: block2, capacity: 70000 * 10**8,
                                     tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5, cell_type: "udt", lock_script_id: address5_lock.id, type_script_id: type_script5.id)
      output1.update(type_hash: CKB::Types::Script.new(**output1.type_script.to_node).compute_hash)
      output2.update(type_hash: CKB::Types::Script.new(**output2.type_script.to_node).compute_hash)
      output3.update(type_hash: CKB::Types::Script.new(**output3.type_script.to_node).compute_hash)
      output4.update(type_hash: CKB::Types::Script.new(**output4.type_script.to_node).compute_hash)
      output5.update(type_hash: CKB::Types::Script.new(**output5.type_script.to_node).compute_hash)
      Address.create(lock_hash: udt_script1.args, address_hash: "0x#{SecureRandom.hex(32)}")
      Address.create(lock_hash: udt_script2.args, address_hash: "0x#{SecureRandom.hex(32)}")

      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")

      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %w[0x 0x 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs, outputs_data: %w[0x 0x 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)
      udt1 = Udt.find_by(args: udt_script1.args)
      udt2 = Udt.find_by(args: udt_script2.args)
      CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(block.number + 1)
      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_data_processor.call
      end
      assert_equal 3, udt1.reload.ckb_transactions_count
      assert_equal 2, udt2.reload.ckb_transactions_count
    end

    test "should remove block's contained address's tx cache when block is invalid" do
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 2)
      tx1 = create(:ckb_transaction, block: block1)
      block2 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx2 = create(:ckb_transaction, block: block2)
      tx3 = create(:ckb_transaction, block: block2)
      tx4 = create(:ckb_transaction, block: block2)
      tx5 = create(:ckb_transaction, block: block2)
      input_address1 = create(:address, balance: 50000 * 10**8)
      input_address2 = create(:address, balance: 60000 * 10**8)
      input_address3 = create(:address, balance: 70000 * 10**8)
      input_address4 = create(:address, balance: 70000 * 10**8)
      input_address5 = create(:address, balance: 70000 * 10**8)
      lock = create(:lock_script)
      create(:cell_output, ckb_transaction: tx1, block: block1, capacity: 50000 * 10**8,
                           tx_hash: tx1.tx_hash, cell_index: 0, address: input_address1, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx2, block: block2, capacity: 60000 * 10**8,
                           tx_hash: tx2.tx_hash, cell_index: 1, address: input_address2, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx3, block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx3.tx_hash, cell_index: 2, address: input_address3, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx4, block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx4.tx_hash, cell_index: 0, address: input_address4, lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: tx5, block: block2, capacity: 70000 * 10**8,
                           tx_hash: tx5.tx_hash, cell_index: 0, address: input_address5, lock_script_id: lock.id)
      header = CKB::Types::BlockHeader.new(compact_target: "0x1000", hash: "0x#{SecureRandom.hex(32)}",
                                           number: DEFAULT_NODE_BLOCK_NUMBER, parent_hash: "0x#{SecureRandom.hex(32)}", nonce: 1757392074788233522, timestamp: CkbUtils.time_in_milliseconds(Time.current), transactions_root: "0x#{SecureRandom.hex(32)}", proposals_hash: "0x#{SecureRandom.hex(32)}", extra_hash: "0x#{SecureRandom.hex(32)}", version: 0, epoch: 1, dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000")
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx2.tx_hash, index: 1)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx3.tx_hash, index: 2))
      ]
      inputs1 = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx4.tx_hash, index: 0)),
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx5.tx_hash, index: 0))
      ]
      lock1 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock2 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      lock3 = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                     args: "0x#{SecureRandom.hex(20)}")
      dao_type = CKB::Types::Script.new(code_hash: Settings.dao_type_hash, hash_type: "type", args: "0x")
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      outputs1 = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock2, type: dao_type),
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock3)
      ]
      miner_lock = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, hash_type: "type",
                                          args: "0x#{SecureRandom.hex(20)}")
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %w[0x0000000000000000 0x0000000000000000 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs1,
                                    outputs: outputs1, outputs_data: %w[0x0000000000000000 0x0000000000000000 0x], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      Sidekiq::Testing.inline!
      block = node_data_processor.process_block(node_block)
      CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(block.number + 1)

      VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
        node_data_processor.call
        AccountBook.where(ckb_transaction_id: block.ckb_transactions.pluck(:id)).pluck(:address_id).uniq.each do |id|
          assert_equal 0, $redis.zcard("Address/txs/#{id}")
        end
      end
    end

    test "#process_block should generate tx display input info" do
      Sidekiq::Testing.inline!
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      create(:block, :with_block_hash, number: 1)
      address = create(:address)
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction,
                                tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction,
                                tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      lock = create(:lock_script)
      create(:cell_output, ckb_transaction: ckb_transaction1,
                           cell_index: 1,
                           tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",
                           block: block,
                           capacity: 10**8 * 1000,
                           address: address,
                           lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: ckb_transaction2,
                           cell_index: 2,
                           tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",
                           block: block,
                           capacity: 10**8 * 1000,
                           address: address,
                           lock_script_id: lock.id)
      tx1 = node_block.transactions.first
      output1 = tx1.outputs.first
      output1.type = CKB::Types::Script.new(args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type",
                                            code_hash: Settings.dao_type_hash)
      output1.capacity = 10**8 * 1000
      tx1.outputs << output1
      tx1.outputs_data << CKB::Utils.bin_to_hex("\x00" * 8)
    end

    test "#process_block should regenerate tx display input info" do
      Sidekiq::Testing.inline!
      CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x2faf0be8")
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      create(:block, :with_block_hash, number: node_block.header.number - 11)
      address = create(:address)
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction,
                                tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",
                                block: block)
      ckb_transaction2 = create(:ckb_transaction,
                                tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",
                                block: block)
      lock = create(:lock_script)
      create(:cell_output, ckb_transaction: ckb_transaction1,
                           cell_index: 1,
                           tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",
                           block: block,
                           capacity: 10**8 * 1000,
                           address: address,
                           lock_script_id: lock.id)
      create(:cell_output, ckb_transaction: ckb_transaction2,
                           cell_index: 2,
                           tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3",
                           block: block,
                           capacity: 10**8 * 1000,
                           address: address,
                           lock_script_id: lock.id)
      tx1 = node_block.transactions.first
      output1 = tx1.outputs.first
      output1.type = CKB::Types::Script.new(
        args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3",
        hash_type: "type",
        code_hash: Settings.dao_type_hash
      )
      output1.capacity = 10**8 * 1000
      tx1.outputs << output1
      tx1.outputs_data << CKB::Utils.bin_to_hex("\x00" * 8)
    end

    test "should update nrc factory cell info" do
      old_factory_cell = create(:nrc_factory_cell, verified: true)
      factory_cell_script = CKB::Types::Script.new(
        code_hash: old_factory_cell.code_hash,
        hash_type: "type",
        args: old_factory_cell.args
      )
      type_script1 = create(:type_script, args: factory_cell_script.args,
                                          code_hash: factory_cell_script.code_hash,
                                          hash_type: "type")
      block1 = create(:block, :with_block_hash, number: DEFAULT_NODE_BLOCK_NUMBER - 1)
      tx1 = create(:ckb_transaction, block: block1)
      input_address1 = create(:address)
      address1_lock = create(:lock_script, address_id: input_address1.id,
                                           args: "0x#{SecureRandom.hex(20)}",
                                           code_hash: Settings.secp_cell_type_hash,
                                           hash_type: "type")
      output1 = create(:cell_output, ckb_transaction: tx1,
                                     block: block1, capacity: 50000 * 10**8,
                                     tx_hash: tx1.tx_hash,
                                     cell_index: 0,
                                     address: input_address1,
                                     cell_type: "nrc_721_factory",
                                     lock_script_id: address1_lock.id,
                                     type_script_id: type_script1.id)
      output1.update(type_hash: CKB::Types::Script.new(**output1.type_script.to_node).compute_hash)
      lock1 = CKB::Types::Script.new(
        code_hash: Settings.secp_cell_type_hash,
        hash_type: "type",
        args: address1_lock.args
      )

      header = CKB::Types::BlockHeader.new(
        compact_target: "0x1000",
        hash: "0x#{SecureRandom.hex(32)}",
        number: DEFAULT_NODE_BLOCK_NUMBER,
        parent_hash: "0x#{SecureRandom.hex(32)}",
        nonce: 1757392074788233522,
        timestamp: CkbUtils.time_in_milliseconds(Time.current),
        transactions_root: "0x#{SecureRandom.hex(32)}",
        proposals_hash: "0x#{SecureRandom.hex(32)}",
        extra_hash: "0x#{SecureRandom.hex(32)}",
        version: 0,
        epoch: 1,
        dao: "0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000"
      )
      inputs = [
        CKB::Types::Input.new(previous_output: CKB::Types::OutPoint.new(tx_hash: tx1.tx_hash, index: 0))
      ]
      outputs = [
        CKB::Types::Output.new(capacity: 40000 * 10**8, lock: lock1, type: factory_cell_script)
      ]
      miner_lock = CKB::Types::Script.new(
        code_hash: Settings.secp_cell_type_hash,
        hash_type: "type",
        args: "0x#{SecureRandom.hex(20)}"
      )
      cellbase_inputs = [
        CKB::Types::Input.new(
          previous_output: CKB::Types::OutPoint.new(
            tx_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 4294967295
          ), since: 3000
        )
      ]
      cellbase_outputs = [
        CKB::Types::Output.new(capacity: 200986682127, lock: miner_lock)
      ]
      transactions = [
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [],
                                    inputs: cellbase_inputs, outputs: cellbase_outputs, outputs_data: %w[0x], witnesses: ["0x590000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd800000000"]),
        CKB::Types::Transaction.new(hash: "0x#{SecureRandom.hex(32)}", cell_deps: [], header_deps: [], inputs: inputs,
                                    outputs: outputs, outputs_data: %w[0x24ff5a9ab8c38d195ce2b4ea75ca89870009522b4b205631204e310009522b4b205631204e3100156465762e6b6f6c6c6563742e6d652f746f6b656e73000000030000000100000000], witnesses: ["0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000"])
      ]
      node_block = CKB::Types::Block.new(uncles: [], proposals: [], transactions: transactions, header: header)
      block = node_data_processor.process_block(node_block)
      assert_equal "R+K V1 N1", old_factory_cell.reload.symbol
    end

    private

    def node_data_processor
      CkbSync::NewNodeDataProcessor.new
    end

    def fake_dao_withdraw_transaction(node_block)
      block = create(:block, :with_block_hash, timestamp: 1557382351075)
      ckb_transaction1 = create(:ckb_transaction,
                                tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction,
                                tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      lock = create(:lock_script)
      cell_output1 = create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1,
                                          tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, cell_type: "nervos_dao_withdrawing", capacity: 10**8 * 1000, data: CKB::Utils.bin_to_hex("\x02" * 8), lock_script_id: lock.id)
      cell_output2 = create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 1,
                                          tx_hash: "0x398315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e2", block: block, consumed_by: ckb_transaction2, cell_type: "nervos_dao_deposit", capacity: 10**8 * 1000, data: CKB::Utils.bin_to_hex("\x00" * 8), lock_script_id: lock.id)
      cell_output3 = create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2,
                                          tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, lock_script_id: lock.id)
      cell_output1.address.update(balance: 10**8 * 1000)
      cell_output2.address.update(balance: 10**8 * 1000)
      cell_output3.address.update(balance: 10**8 * 1000)
      create(:cell_input, block: ckb_transaction2.block, ckb_transaction: ckb_transaction2,
                          previous_output: { "tx_hash": "0x398315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e2", "index": "1" })
      create(:cell_input, block: ckb_transaction2.block, ckb_transaction: ckb_transaction2,
                          previous_output: { "tx_hash": "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", "index": "2" })
      create(:cell_input, block: ckb_transaction1.block, ckb_transaction: ckb_transaction1,
                          previous_output: { "tx_hash": "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", "index": "1" })
      create(:cell_input, block: ckb_transaction1.block, ckb_transaction: ckb_transaction1,
                          previous_output: { "tx_hash": "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", "index": "1" })

      tx = node_block.transactions.last
      tx.header_deps = ["0x0b3e980e4e5e59b7d478287e21cd89ffdc3ff5916ee26cf2aa87910c6a504d61"]
      tx.witnesses = %w(
        0x8ae8061ec879d66c0f3996ab60d7c2a21094b8739817beddaea1e28d3620a70a21497a692581ca352631a67f3f6659a7c47d9a0c6c2def79d3e39440918a66fef 0x4e52933358ae2f26863b8c1c71bf20f17489328820f8f2cd84a070069f10ceef784bc3693c3c51b93475a7b5dbf652ba6532d0580ecc1faf909f9fd53c5f6405000000000000000000
      )

      ckb_transaction1
    end

    def fake_dao_deposit_transaction(node_block)
      block = create(:block, :with_block_hash, timestamp: 1557382351075)
      lock = create(:lock_script)
      ckb_transaction1 = create(:ckb_transaction,
                                tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction,
                                tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      cell_output1 = create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1,
                                          tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, capacity: 10**8 * 1000, lock_script_id: lock.id)
      cell_output2 = create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2,
                                          tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block, capacity: 10**8 * 1000, lock_script_id: lock.id)
      cell_output1.address.update(balance: 10**8 * 1000)
      cell_output2.address.update(balance: 10**8 * 1000)
      tx = node_block.transactions.first
      output = tx.outputs.first
      output.type = CKB::Types::Script.new(args: "0xb2e61ff569acf041b3c2c17724e2379c581eeac3", hash_type: "type",
                                           code_hash: Settings.dao_type_hash)
      tx.outputs_data[0] = CKB::Utils.bin_to_hex("\x00" * 8)
      output.capacity = 10**8 * 1000

      tx
    end
  end
end
