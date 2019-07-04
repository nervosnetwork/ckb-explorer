module CkbSync
  class Persist
    class << self
      def call(block_hash, sync_type = "inauthentic")
        node_block = CkbSync::Api.instance.get_block(block_hash)
        save_block(node_block, sync_type)
      end

      def sync(block_number)
        node_block = CkbSync::Api.instance.get_block_by_number(block_number)
        save_block(node_block, "inauthentic")
      end

      def save_block(node_block, sync_type)
        local_block = build_block(node_block, sync_type)

        node_block.uncles.each do |uncle_block|
          build_uncle_block(uncle_block, local_block)
        end

        ApplicationRecord.transaction do
          SyncInfo.find_by!(name: sync_tip_block_number_type(sync_type), value: local_block.number).update_attribute(:status, "synced")
          ckb_transactions = build_ckb_transactions(local_block, node_block.transactions, sync_type)
          Block.import! [local_block], recursive: true, batch_size: 1000, validate: false

          local_block.reload.ckb_transactions_count = ckb_transactions.size
          local_block.address_ids = AccountBook.where(ckb_transaction: local_block.ckb_transactions).pluck(:address_id).uniq
          local_block.save!
          update_pending_rewards(local_block.miner_address)
        end

        local_block
      end

      def update_ckb_transaction_info_and_fee
        update_ckb_transaction_info
        update_ckb_transaction_fee
      end

      def update_ckb_transaction_info
        display_inputs_ckb_transaction_ids = CkbTransaction.ungenerated.limit(500).ids.map { |ids| [ids] }
        Sidekiq::Client.push_bulk("class" => "UpdateTransactionDisplayInfosWorker", "args" => display_inputs_ckb_transaction_ids, "queue" => "transaction_info_updater") if display_inputs_ckb_transaction_ids.present?
      end

      def update_ckb_transaction_fee
        transaction_fee_ckb_transaction_ids = CkbTransaction.uncalculated.limit(500).ids.map { |ids| [ids] }
        Sidekiq::Client.push_bulk("class" => "UpdateTransactionFeeWorker", "args" => transaction_fee_ckb_transaction_ids, "queue" => "transaction_info_updater") if transaction_fee_ckb_transaction_ids.present?
      end

      def update_ckb_transaction_display_inputs(ckb_transaction)
        display_inputs = Set.new
        cell_input_addresses = Set.new

        ckb_transaction.cell_inputs.find_each do |cell_input|
          display_inputs << build_display_input(cell_input)
          cell_input_addresses << cell_input_address(cell_input)
        end

        assign_display_inputs(ckb_transaction, display_inputs.to_a)
        cell_input_address_arr = cell_input_addresses.delete(nil).to_a

        ckb_transaction.addresses << cell_input_address_arr if cell_input_address_arr.present?

        ckb_transaction.save
      end

      def update_ckb_transaction_display_outputs(ckb_transaction)
        display_outputs = []
        if ckb_transaction.is_cellbase
          cell_output = ckb_transaction.cell_outputs.first
          cellbase = Cellbase.new(ckb_transaction.block)
          display_outputs << { id: cell_output.id, capacity: cell_output.capacity, address_hash: cell_output.address_hash, target_block_number: cellbase.target_block_number, block_reward: cellbase.block_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward }
        else
          ckb_transaction.cell_outputs.find_each do |cell_output|
            display_outputs << { id: cell_output.id, capacity: cell_output.capacity, address_hash: cell_output.address_hash }
          end
        end

        ckb_transaction.display_outputs = display_outputs

        ckb_transaction.save
      end

      def update_transaction_fee(ckb_transaction)
        transaction_fee = CkbUtils.ckb_transaction_fee(ckb_transaction)
        return if transaction_fee.blank?

        assign_ckb_transaction_fee(ckb_transaction, transaction_fee)
        ApplicationRecord.transaction do
          ckb_transaction.save!
          block = ckb_transaction.block
          block.total_transaction_fee = block.ckb_transactions.sum(:transaction_fee)
          block.save!
        end
      end

      def update_address_balance_and_ckb_transactions_count(address)
        address.balance = address.cell_outputs.live.sum(:capacity)
        address.ckb_transactions_count = address.ckb_transactions.available.distinct.count
        address.save
      end

      def update_block_address_ids_and_cell_status(ckb_transaction)
        update_cell_status(ckb_transaction)
        update_block_address_ids(ckb_transaction)
      end

      def update_block_reward_info(current_block)
        target_block_number = current_block.target_block_number
        target_block = current_block.target_block
        return if target_block_number < 1 || target_block.blank? || target_block.exist_uncalculated_tx?

        ApplicationRecord.transaction do
          issue_block_reward!(current_block)
          CkbUtils.update_target_block_miner_address_pending_rewards(current_block)
        end
        current_block_cellbase = current_block.cellbase
        update_ckb_transaction_display_outputs(current_block_cellbase)
        update_ckb_transaction_display_inputs(current_block_cellbase)
      end

      private

      def issue_block_reward!(current_block)
        CkbUtils.update_block_reward_status!(current_block)
        CkbUtils.calculate_received_tx_fee!(current_block)
      end

      def update_pending_rewards(miner_address)
        CkbUtils.update_current_block_miner_address_pending_rewards(miner_address)
      end

      def update_cell_status(ckb_transaction)
        previous_cell_output_ids = CellInput.where(ckb_transaction: ckb_transaction).select("previous_cell_output_id")
        previous_cell_outputs = CellOutput.where(id: previous_cell_output_ids)
        previous_cell_outputs.update_all(status: :dead)
        cell_output_ids = ckb_transaction.cell_outputs.select("id")
        cell_outputs = CellOutput.where(id: previous_cell_output_ids + cell_output_ids)
        address_ids = cell_outputs.pluck(:address_id)

        Sidekiq::Client.push_bulk("class" => "UpdateAddressInfoWorker", "args" => address_ids.map { |ids| [ids] }, "queue" => "address_info_updater")
      end

      def update_block_address_ids(ckb_transaction)
        cell_output_ids = CellInput.where(ckb_transaction: ckb_transaction).select("previous_cell_output_id")
        address_ids = CellOutput.where(id: cell_output_ids).pluck("address_id")
        return if address_ids.empty?

        ApplicationRecord.transaction do
          block_address_ids = Set.new
          block = ckb_transaction.block
          block.lock!
          block_address_ids += block.address_ids
          block_address_ids += address_ids
          block.address_ids = block_address_ids.to_a
          block.save!
        end

        Sidekiq::Client.push_bulk("class" => "UpdateAddressInfoWorker", "args" => address_ids.map { |ids| [ids] }, "queue" => "address_info_updater")
      end

      def assign_ckb_transaction_fee(ckb_transaction, transaction_fee)
        if transaction_fee.present?
          ckb_transaction.transaction_fee = transaction_fee
          ckb_transaction.transaction_fee_status = "calculated"
        end
      end

      def assign_display_inputs(ckb_transaction, display_inputs)
        if !display_inputs.include?(nil)
          ckb_transaction.display_inputs = display_inputs
          ckb_transaction.display_inputs_status = "generated"
          UpdateBlockInfoWorker.perform_async(ckb_transaction.id)
        end
      end

      def cell_input_address(cell_input)
        previous_cell_output = cell_input.previous_cell_output

        return if previous_cell_output.blank?

        previous_cell_output.address
      end

      def build_ckb_transactions(local_block, transactions, sync_type)
        ckb_transactions = []
        transaction_index = 0
        transactions.each do |transaction|
          addresses = Set.new
          ckb_transaction = build_ckb_transaction(local_block, transaction, sync_type, transaction_index)
          ckb_transactions << ckb_transaction

          build_cell_inputs(transaction.inputs, ckb_transaction)
          build_cell_outputs(transaction.outputs, ckb_transaction, addresses)
          addresses_arr = addresses.to_a
          ckb_transaction.addresses << addresses_arr
          transaction_index += 1
        end

        ckb_transactions
      end

      def build_cell_inputs(node_inputs, ckb_transaction)
        node_inputs.each do |input|
          build_cell_input(ckb_transaction, input)
        end
      end

      def build_cell_outputs(node_outputs, ckb_transaction, addresses)
        cell_index = 0
        node_outputs.each do |output|
          address = Address.find_or_create_address(output.lock)
          cell_output = build_cell_output(ckb_transaction, output, address, cell_index)
          build_lock_script(cell_output, output.lock, address)
          build_type_script(cell_output, output.type)
          addresses << address
          cell_index += 1
        end
      end

      def sync_tip_block_number_type(sync_type)
        "#{sync_type}_tip_block_number"
      end

      def build_display_input(cell_input)
        cell = cell_input.previous_output["cell"]

        if cell.blank?
          cellbase = Cellbase.new(cell_input.ckb_transaction.block)
          { id: nil, from_cellbase: true, capacity: nil, address_hash: nil, target_block_number: cellbase.target_block_number }
        else
          previous_cell_output = cell_input.previous_cell_output

          return if previous_cell_output.blank?

          cell_input.update(previous_cell_output_id: previous_cell_output.id)
          address_hash = previous_cell_output.address_hash
          { id: cell_input.id, from_cellbase: false, capacity: previous_cell_output.capacity, address_hash: address_hash }
        end
      end

      def build_type_script(cell_output, type_script)
        return if type_script.blank?

        cell_output.build_type_script(
          args: type_script.args,
          code_hash: type_script.code_hash
        )
      end

      def build_lock_script(cell_output, verify_script, address)
        cell_output.build_lock_script(
          args: verify_script.args,
          code_hash: verify_script.code_hash,
          address: address
        )
      end

      def build_cell_input(ckb_transaction, input)
        ckb_transaction.cell_inputs.build(
          previous_output: input.previous_output,
          since: input.since,
          from_cell_base: input.previous_output.cell.blank?
        )
      end

      def build_cell_output(ckb_transaction, output, address, cell_index)
        ckb_transaction.cell_outputs.build(
          capacity: output.capacity,
          data: output.data,
          address: address,
          block: ckb_transaction.block,
          tx_hash: ckb_transaction.tx_hash,
          cell_index: cell_index
        )
      end

      def uncle_block_hashes(node_block_uncles)
        node_block_uncles.map { |uncle| uncle.to_h.dig("header", "hash") }
      end

      def build_block(node_block, sync_type)
        header = node_block.header
        epoch_info = CkbUtils.get_epoch_info(header.epoch)
        cellbase = node_block.transactions.first

        generate_address_in_advance(cellbase)

        Block.new(
          difficulty: header.difficulty,
          block_hash: header.hash,
          number: header.number,
          parent_hash: header.parent_hash,
          seal: header.seal,
          timestamp: header.timestamp,
          transactions_root: header.transactions_root,
          proposals_hash: header.proposals_hash,
          uncles_count: header.uncles_count,
          uncles_hash: header.uncles_hash,
          uncle_block_hashes: uncle_block_hashes(node_block.uncles),
          version: header.version,
          proposals: node_block.proposals,
          proposals_count: node_block.proposals.count,
          cell_consumed: CkbUtils.block_cell_consumed(node_block.transactions),
          total_cell_capacity: CkbUtils.total_cell_capacity(node_block.transactions),
          miner_hash: CkbUtils.miner_hash(cellbase),
          status: sync_type,
          reward: CkbUtils.base_reward(header.number, header.epoch, node_block.transactions.first),
          reward_status: header.number.to_i == 0 ? "issued" : "pending",
          total_transaction_fee: 0,
          witnesses_root: header.witnesses_root,
          epoch: header.epoch,
          start_number: epoch_info.start_number,
          length: epoch_info.length
        )
      end

      def generate_address_in_advance(cellbase)
        return if cellbase.witnesses.blank?

        lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
        address = Address.find_or_create_address(lock_script)
        LockScript.find_or_create_by(
          args: lock_script.args,
          code_hash: lock_script.code_hash,
          address: address
        )
      end

      def build_uncle_block(uncle_block, local_block)
        header = uncle_block.header
        local_block.uncle_blocks.build(
          difficulty: header.difficulty,
          block_hash: header.hash,
          number: header.number,
          parent_hash: header.parent_hash,
          seal: header.seal,
          timestamp: header.timestamp,
          transactions_root: header.transactions_root,
          proposals_hash: header.proposals_hash,
          uncles_count: header.uncles_count,
          uncles_hash: header.uncles_hash,
          version: header.version,
          proposals: uncle_block.proposals,
          proposals_count: uncle_block.proposals.count,
          witnesses_root: header.witnesses_root,
          epoch: header.epoch
        )
      end

      def build_ckb_transaction(local_block, transaction, sync_type, transaction_index)
        local_block.ckb_transactions.build(
          tx_hash: transaction.hash,
          deps: transaction.deps,
          version: transaction.version,
          block_number: local_block.number,
          block_timestamp: local_block.timestamp,
          status: sync_type,
          transaction_fee: 0,
          witnesses: transaction.witnesses.map(&:to_h),
          is_cellbase: transaction_index.zero?
        )
      end
    end
  end
end
