module CkbSync
  class NodeDataProcessor
    def call
      local_tip_block = Block.recent.first
      tip_block_number = CkbSync::Api.instance.get_tip_block_number
      target_block_number = local_tip_block.present? ? local_tip_block.number + 1 : 0
      return if target_block_number > tip_block_number

      target_block = CkbSync::Api.instance.get_block_by_number(target_block_number)
      if !forked?(target_block, local_tip_block)
        process_block(target_block)
      else
        invalid_block(local_tip_block)
      end
    end

    def process_block(node_block)
      local_block = build_block(node_block)
      node_block.uncles.each do |uncle_block|
        build_uncle_block(uncle_block, local_block)
      end

      ApplicationRecord.transaction do
        outputs = []
        udt_infos = Set.new
        new_dao_depositor_events = {}
        local_block.save!
        ckb_transactions = build_ckb_transactions(local_block, node_block.transactions, outputs,
                                                  new_dao_depositor_events, udt_infos)
        local_block.ckb_transactions_count = ckb_transactions.size
        local_block.live_cell_changes = ckb_transactions.sum(&:live_cell_changes)
        CkbTransaction.import!(ckb_transactions, recursive: true, batch_size: 3500, validate: false)
        update_pool_tx_status(ckb_transactions)
        input_capacities = ckb_transactions.reject(&:is_cellbase).pluck(:id).index_with { |_id| [] }
        update_tx_fee_related_data(local_block, input_capacities, udt_infos)
        calculate_tx_fee(local_block, ckb_transactions, input_capacities, outputs.group_by(&:ckb_transaction_id))
        update_current_block_mining_info(local_block)
        update_block_contained_address_info(local_block)
        update_block_reward_info(local_block)
        update_udt_accounts(udt_infos, local_block.timestamp)
        update_udt_info(udt_infos)
        dao_events = build_new_dao_depositor_events(new_dao_depositor_events)
        DaoEvent.import!(dao_events, validate: false)
        update_dao_contract_related_info(local_block)
        increase_records_count(ckb_transactions)
        cache_address_txs(local_block.ckb_transactions)
      end
      local_block
    end

    private

    def cache_address_txs(ckb_transactions)
      address_txs = Hash.new
      ckb_transactions.each do |tx|
        tx.contained_address_ids.each do |id|
          if address_txs[id].present?
            address_txs[id] << tx.id
          else
            address_txs[id] = [tx.id]
          end
        end
      end

      AddressTxsCacheUpdateWorker.perform_async(address_txs)
    end

    def update_pool_tx_status(ckb_transactions)
      PoolTransactionEntry.pool_transaction_pending.where(tx_hash: ckb_transactions.pluck(:tx_hash)).update_all(tx_status: "committed")
    end

    def increase_records_count(ckb_transactions)
      block_counter = TableRecordCount.find_or_initialize_by(table_name: "blocks")
      block_counter.increment!(:count)
      ckb_transaction_counter = TableRecordCount.find_or_initialize_by(table_name: "ckb_transactions")
      normal_transactions = ckb_transactions.reject { |tx| tx.is_cellbase }
      ckb_transaction_counter.increment!(:count, normal_transactions.count) if normal_transactions.present?
    end

    def update_udt_info(udt_infos)
      return if udt_infos.blank?

      type_hashes = udt_infos.map { |udt_info| udt_info[:type_script].compute_hash }.uniq
      columns = %i(type_hash total_amount addresses_count)
      amount_hashes = UdtAccount.where(type_hash: type_hashes).group(:type_hash).sum(:amount)
      addresses_count_hashes = UdtAccount.where(type_hash: type_hashes).group(:type_hash).count(:address_id)
      import_values =
        type_hashes.map do |type_hash|
          [type_hash, amount_hashes[type_hash], addresses_count_hashes[type_hash]]
        end

      Udt.import columns, import_values, validate: false,
                                         on_duplicate_key_update: { conflict_target: [:type_hash], columns: [:total_amount, :addresses_count] }
    end

    def update_udt_accounts(udt_infos, block_timestamp)
      return if udt_infos.blank?

      udt_infos.each do |udt_output|
        address = udt_output[:address]
        udt_type_script = udt_output[:type_script]
        udt_type = udt_output[:udt_type]
        type_hash = udt_type_script.compute_hash
        udt_account = address.udt_accounts.find_by(type_hash: type_hash, udt_type: udt_type)
        if udt_type == "sudt"
          amount = address.cell_outputs.live.udt.where(type_hash: type_hash).sum(:udt_amount)
        elsif udt_type == "m_nft_token"
          amount = address.cell_outputs.live.m_nft_token.where(type_hash: type_hash).sum(:udt_amount)
        else
          amount = 0
        end

        if udt_account.present?
          case udt_type
          when "sudt"
            udt_account.update!(amount: amount)
          when "m_nft_token"
            udt_account.destroy unless address.cell_outputs.live.m_nft_token.where(type_hash: type_hash).exists?
          end
        else
          udt = Udt.find_or_create_by!(type_hash: type_hash, udt_type: udt_type)
          udt.update(block_timestamp: block_timestamp) if udt.block_timestamp.blank?
          if udt.udt_type == "sudt" && udt.issuer_address.blank?
            issuer_address = Address.where(lock_hash: udt_type_script.args).pick(:address_hash)
            udt.issuer_address = issuer_address
          end
          udt.update(args: udt_type_script.args, hash_type: udt_type_script.hash_type,
                     issuer_address: udt.issuer_address)
          address.udt_accounts.create!(udt_type: udt.udt_type, full_name: udt.full_name, symbol: udt.symbol,
                                       decimal: udt.decimal, published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount, udt: udt)
        end
      end
    end

    def build_new_dao_depositor_events(new_dao_depositor_events)
      new_dao_depositor_events.map do |address_id, tx_hash|
        ckb_transaction = CkbTransaction.find_by(tx_hash: tx_hash)
        ckb_transaction.dao_events.build(block: ckb_transaction.block, address_id: address_id, event_type: "new_dao_depositor",
                                         value: 1, contract_id: DaoContract.default_contract.id, block_timestamp: ckb_transaction.block_timestamp)
      end
    end

    def update_dao_contract_related_info(local_block)
      dao_contract = DaoContract.default_contract
      dao_events = DaoEvent.where(block: local_block).pending
      process_deposit_to_dao(dao_contract, dao_events)
      process_new_dao_depositor(dao_contract, dao_events)
      process_withdraw_from_dao(dao_contract, dao_events)
      process_issue_interest(dao_contract, dao_events)
      process_take_away_all_deposit(dao_contract, dao_events)
      dao_contract.touch
    end

    def process_take_away_all_deposit(dao_contract, dao_events)
      take_away_all_deposit_dao_events = dao_events.where(event_type: "take_away_all_deposit")
      take_away_all_deposit_dao_events.each do |event|
        dao_contract.decrement!(:depositors_count)
        event.address.update(is_depositor: false)
        event.processed!
      end
    end

    def process_issue_interest(dao_contract, dao_events)
      issue_interest_dao_events = dao_events.where(event_type: "issue_interest")
      issue_interest_dao_events.each do |event|
        dao_contract.increment!(:claimed_compensation, event.value)
        address = event.address
        address.increment!(:interest, event.value)
        event.processed!
      end
    end

    def process_withdraw_from_dao(dao_contract, dao_events)
      withdraw_from_dao_events = dao_events.where(event_type: "withdraw_from_dao")
      withdraw_from_dao_events.each do |event|
        dao_contract.increment!(:withdraw_transactions_count)
        dao_contract.decrement!(:total_deposit, event.value)
        address = event.address
        address.decrement!(:dao_deposit, event.value)
        event.processed!
      end
    end

    def process_new_dao_depositor(dao_contract, dao_events)
      new_dao_depositor_events = dao_events.where(event_type: "new_dao_depositor")
      new_dao_depositor_events.each do |event|
        dao_contract.increment!(:depositors_count)
        dao_contract.increment!(:total_depositors_count)
        event.address.update(is_depositor: true)
        event.processed!
      end
    end

    def process_deposit_to_dao(dao_contract, dao_events)
      deposit_to_dao_events = dao_events.where(event_type: "deposit_to_dao")
      deposit_to_dao_events.each do |event|
        address = event.address
        address.increment!(:dao_deposit, event.value)
        dao_contract.increment!(:total_deposit, event.value)
        dao_contract.increment!(:deposit_transactions_count)
        event.processed!
      end
    end

    def update_block_reward_info(current_block)
      target_block_number = current_block.target_block_number
      target_block = current_block.target_block
      return if target_block_number < 1 || target_block.blank?

      ApplicationRecord.transaction do
        issue_block_reward!(current_block)
      end
    end

    def issue_block_reward!(current_block)
      CkbUtils.update_block_reward!(current_block)
      CkbUtils.calculate_received_tx_fee!(current_block)
    end

    def revert_block_rewards(local_tip_block)
      target_block = local_tip_block.target_block
      target_block_number = local_tip_block.target_block_number
      return if target_block_number < 1 || target_block.blank?

      revert_reward_status(target_block)
      revert_received_tx_fee(target_block)
    end

    def revert_received_tx_fee(target_block)
      target_block.update!(received_tx_fee: 0)
    end

    def revert_reward_status(target_block)
      target_block.update!(reward_status: "pending")
      target_block.update!(received_tx_fee_status: "pending")
    end

    def invalid_block(local_tip_block)
      ApplicationRecord.transaction do
        revert_dao_contract_related_operations(local_tip_block)
        revert_mining_info(local_tip_block)
        udt_type_hashes = local_tip_block.cell_outputs.udt.pluck(:type_hash).uniq.concat(local_tip_block.cell_outputs.m_nft_token.pluck(:type_hash).uniq)
        recalculate_udt_transactions_count(local_tip_block)
        recalculate_dao_contract_transactions_count(local_tip_block)
        decrease_records_count(local_tip_block)
        local_tip_block.invalid!
        recalculate_udt_accounts(udt_type_hashes, local_tip_block)
        local_tip_block.contained_addresses.each(&method(:update_address_balance_and_ckb_transactions_count))
        revert_block_rewards(local_tip_block)
        ForkedEvent.create!(block_number: local_tip_block.number, epoch_number: local_tip_block.epoch,
                            block_timestamp: local_tip_block.timestamp)
        Charts::BlockStatisticGenerator.new(local_tip_block.number).call

        local_tip_block
      end
    end

    def decrease_records_count(local_tip_block)
      block_counter = TableRecordCount.find_or_initialize_by(table_name: "blocks")
      block_counter.decrement!(:count)
      ckb_transaction_counter = TableRecordCount.find_or_initialize_by(table_name: "ckb_transactions")
      normal_transactions = local_tip_block.ckb_transactions.normal
      ckb_transaction_counter.decrement!(:count, normal_transactions.count) if normal_transactions.present?
    end

    def recalculate_dao_contract_transactions_count(local_tip_block)
      dao_transactions_count = local_tip_block.ckb_transactions.where("tags @> array[?]::varchar[]", ["dao"]).count
      if dao_transactions_count > 0
        DaoContract.default_contract.decrement!(:ckb_transactions_count,
                                                dao_transactions_count)
      end
    end

    def recalculate_udt_transactions_count(local_tip_block)
      udt_ids = local_tip_block.ckb_transactions.where("tags @> array[?]::varchar[]",
                                                       ["udt"]).pluck(:contained_udt_ids).flatten
      udt_counts = udt_ids.each_with_object(Hash.new(0)) { |udt_id, counts| counts[udt_id] += 1 }
      udt_counts_value =
        udt_counts.map do |udt_id, count|
          udt = Udt.find(udt_id)
          {
            id: udt_id, ckb_transactions_count: udt.ckb_transactions_count - count, created_at: udt.created_at,
            updated_at: Time.current }
        end

      Udt.upsert_all(udt_counts_value) if udt_counts_value.present?
    end

    def recalculate_udt_accounts(udt_type_hashes, local_tip_block)
      return if udt_type_hashes.blank?

      local_tip_block.contained_addresses.find_each do |address|
        udt_type_hashes.each do |type_hash|
          udt_account = address.udt_accounts.find_by(type_hash: type_hash)
          next if udt_account.blank?

          if udt_account.udt_type == "sudt"
            amount = address.cell_outputs.live.udt.where(type_hash: type_hash).sum(:udt_amount)
            udt_account.update!(amount: amount)
          elsif udt_account.udt_type == "m_nft_token"
            udt_account.destroy
          end
        end
      end
    end

    def revert_mining_info(local_tip_block)
      local_tip_block.mining_infos.first.reverted!
      miner_address = local_tip_block.miner_address
      miner_address.decrement!(:mined_blocks_count)
    end

    def revert_dao_contract_related_operations(local_tip_block)
      dao_events = DaoEvent.where(block: local_tip_block).processed
      dao_contract = DaoContract.default_contract
      revert_withdraw_from_dao(dao_contract, dao_events)
      revert_issue_interest(dao_contract, dao_events)
      revert_deposit_to_dao(dao_contract, dao_events)
      revert_new_dao_depositor(dao_contract, dao_events)
      revert_take_away_all_deposit(dao_contract, dao_events)
    end

    def revert_take_away_all_deposit(dao_contract, dao_events)
      take_away_all_deposit_dao_events = dao_events.where(event_type: "take_away_all_deposit")
      take_away_all_deposit_dao_events.each do |event|
        dao_contract.increment!(:depositors_count)
        event.reverted!
      end
    end

    def revert_issue_interest(dao_contract, dao_events)
      issue_interest_dao_events = dao_events.where(event_type: "issue_interest")
      issue_interest_dao_events.each do |event|
        dao_contract.decrement!(:claimed_compensation, event.value)
        address = event.address
        address.decrement!(:interest, event.value)
        event.reverted!
      end
    end

    def revert_withdraw_from_dao(dao_contract, dao_events)
      withdraw_from_dao_events = dao_events.where(event_type: "withdraw_from_dao")
      withdraw_from_dao_events.each do |event|
        dao_contract.decrement!(:withdraw_transactions_count)
        dao_contract.increment!(:total_deposit, event.value)
        address = event.address
        address.increment!(:dao_deposit, event.value)
        event.reverted!
      end
    end

    def revert_new_dao_depositor(dao_contract, dao_events)
      new_dao_depositor_events = dao_events.where(event_type: "new_dao_depositor")
      new_dao_depositor_events.each do |event|
        dao_contract.decrement!(:depositors_count)
        dao_contract.decrement!(:total_depositors_count)
        event.reverted!
      end
    end

    def revert_deposit_to_dao(dao_contract, dao_events)
      deposit_to_dao_events = dao_events.where(event_type: "deposit_to_dao")
      deposit_to_dao_events.each do |event|
        address = event.address
        address.decrement!(:dao_deposit, event.value)
        dao_contract.decrement!(:total_deposit, event.value)
        dao_contract.decrement!(:deposit_transactions_count)
        event.reverted!
      end
    end

    def update_block_contained_address_info(local_block)
      ApplicationRecord.transaction do
        local_block.address_ids = local_block.ckb_transactions.pluck(:contained_address_ids).flatten.uniq
        local_block.save!
        local_block.contained_addresses.each(&method(:update_address_balance_and_ckb_transactions_count))
      end
    end

    def forked?(target_block, local_tip_block)
      return false if local_tip_block.blank?

      target_block.header.parent_hash != local_tip_block.block_hash
    end

    def uncle_block_hashes(node_block_uncles)
      node_block_uncles.map { |uncle| uncle.header.hash }
    end

    def generate_address_in_advance(cellbase, block_timestamp)
      return if cellbase.witnesses.blank?

      lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
      address = Address.find_or_create_address(lock_script, block_timestamp)
      LockScript.create_or_find_by(
        args: lock_script.args,
        code_hash: lock_script.code_hash,
        hash_type: lock_script.hash_type,
        address: address
      )
    end

    def build_block(node_block)
      header = node_block.header
      epoch_info = CkbUtils.parse_epoch_info(header)
      cellbase = node_block.transactions.first

      generate_address_in_advance(cellbase, header.timestamp)

      Block.new(
        compact_target: header.compact_target,
        block_hash: header.hash,
        number: header.number,
        parent_hash: header.parent_hash,
        nonce: header.nonce,
        timestamp: header.timestamp,
        transactions_root: header.transactions_root,
        proposals_hash: header.proposals_hash,
        uncles_count: node_block.uncles.count,
        uncles_hash: header.uncles_hash,
        uncle_block_hashes: uncle_block_hashes(node_block.uncles),
        version: header.version,
        proposals: node_block.proposals,
        proposals_count: node_block.proposals.count,
        cell_consumed: CkbUtils.block_cell_consumed(node_block.transactions),
        total_cell_capacity: CkbUtils.total_cell_capacity(node_block.transactions),
        miner_hash: CkbUtils.miner_hash(cellbase),
        miner_lock_hash: CkbUtils.miner_lock_hash(cellbase),
        reward: CkbUtils.base_reward(header.number, epoch_info.number),
        primary_reward: CkbUtils.base_reward(header.number, epoch_info.number),
        secondary_reward: 0,
        reward_status: header.number.to_i == 0 ? "issued" : "pending",
        total_transaction_fee: 0,
        epoch: epoch_info.number,
        start_number: epoch_info.start_number,
        length: epoch_info.length,
        dao: header.dao,
        block_time: block_time(header.timestamp, header.number),
        block_size: 0
      )
    end

    def block_time(timestamp, number)
      target_block_number = [number - 1, 0].max
      return 0 if target_block_number.zero?

      previous_block_timestamp = Block.find_by(number: target_block_number).timestamp
      timestamp - previous_block_timestamp
    end

    def build_uncle_block(uncle_block, local_block)
      header = uncle_block.header
      epoch_info = CkbUtils.parse_epoch_info(header)
      local_block.uncle_blocks.build(
        compact_target: header.compact_target,
        block_hash: header.hash,
        number: header.number,
        parent_hash: header.parent_hash,
        nonce: header.nonce,
        timestamp: header.timestamp,
        transactions_root: header.transactions_root,
        proposals_hash: header.proposals_hash,
        uncles_hash: header.uncles_hash,
        version: header.version,
        proposals: uncle_block.proposals,
        proposals_count: uncle_block.proposals.count,
        epoch: epoch_info.number,
        dao: header.dao
      )
    end

    def build_ckb_transactions(local_block, transactions, outputs, new_dao_depositor_events, udt_infos)
      transactions.each_with_index.map do |transaction, transaction_index|
        addresses = Set.new
        address_ids = Set.new
        tags = Set.new
        udt_ids = Set.new
        dao_address_ids = Set.new
        udt_address_ids = Set.new
        ckb_transaction = build_ckb_transaction(local_block, transaction, transaction_index)
        build_cell_inputs(transaction.inputs, ckb_transaction)
        build_cell_outputs(transaction.outputs, ckb_transaction, addresses, transaction.outputs_data, outputs,
                           new_dao_depositor_events, udt_infos, address_ids, tags, udt_ids, dao_address_ids, udt_address_ids)
        ckb_transaction.addresses << addresses.to_a
        ckb_transaction.contained_address_ids += address_ids.to_a
        ckb_transaction.tags += tags.to_a
        ckb_transaction.contained_udt_ids += udt_ids.to_a
        ckb_transaction.dao_address_ids += dao_address_ids.to_a
        ckb_transaction.udt_address_ids += udt_address_ids.to_a

        ckb_transaction
      end
    end

    def build_ckb_transaction(local_block, transaction, transaction_index)
      local_block.ckb_transactions.build(
        tx_hash: transaction.hash,
        cell_deps: transaction.cell_deps,
        header_deps: transaction.header_deps,
        version: transaction.version,
        block_number: local_block.number,
        block_timestamp: local_block.timestamp,
        transaction_fee: 0,
        witnesses: transaction.witnesses,
        is_cellbase: transaction_index.zero?,
        live_cell_changes: live_cell_changes(transaction, transaction_index)
      )
    end

    def live_cell_changes(transaction, transaction_index)
      transaction_index.zero? ? 1 : transaction.outputs.count - transaction.inputs.count
    end

    def build_cell_inputs(node_inputs, ckb_transaction)
      node_inputs.each do |node_input|
        build_cell_input(ckb_transaction, node_input)
      end
    end

    def build_cell_input(ckb_transaction, node_input)
      ckb_transaction.cell_inputs.build(
        previous_output: node_input.previous_output,
        since: node_input.since,
        block: ckb_transaction.block,
        from_cell_base: from_cell_base?(node_input)
      )
    end

    def from_cell_base?(node_input)
      node_input.previous_output.tx_hash == CellOutput::SYSTEM_TX_HASH
    end

    def build_cell_outputs(
      node_outputs, ckb_transaction, addresses, outputs_data, outputs, new_dao_depositor_events,
udt_infos, address_ids, tags, udt_ids, dao_address_ids, udt_address_ids
    )
      node_outputs.each_with_index.map do |output, cell_index|
        address = Address.find_or_create_address(output.lock, ckb_transaction.block_timestamp)
        addresses << address
        address_ids << address.id
        cell_output = build_cell_output(ckb_transaction, output, address, cell_index, outputs_data[cell_index])
        outputs << cell_output
        if cell_output.udt?
          udt_infos << { type_script: output.type, address: address, udt_type: "sudt" }
          tags << "udt"
          udt = Udt.find_or_create_by!(type_hash: output.type.compute_hash, udt_type: "sudt")
          udt_ids << udt.id
          udt_address_ids << address.id
        end
        if cell_output.m_nft_token?
          udt_infos << { type_script: output.type, address: address, udt_type: "m_nft_token" }
          udt = Udt.find_or_create_by!(type_hash: output.type.compute_hash, udt_type: "m_nft_token")
          m_nft_class_type = TypeScript.where(code_hash: CkbSync::Api.instance.token_class_script_code_hash,
                                              args: output.type.args[0..49]).select { |type|
            type.cell_output&.live?
          }.first
          if m_nft_class_type.present?
            m_nft_class_cell = m_nft_class_type.cell_output
            parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
            udt.update(full_name: parsed_class_data.name, icon_file: parsed_class_data.renderer)
          end
          udt.update(published: true)
        end
        if cell_output.nervos_dao_deposit? || cell_output.nervos_dao_withdrawing?
          tags << "dao"
          dao_address_ids << address.id
        end

        build_deposit_dao_events(address, cell_output, ckb_transaction, new_dao_depositor_events)
        build_lock_script(cell_output, output.lock, address)
        build_type_script(cell_output, output.type)

        cell_output
      end
    end

    def build_deposit_dao_events(address, cell_output, ckb_transaction, new_dao_depositor_events)
      if cell_output.nervos_dao_deposit?
        dao_contract = DaoContract.find_or_create_by(id: 1)
        ckb_transaction.dao_events.build(block: ckb_transaction.block, address_id: address.id, event_type: "deposit_to_dao",
                                         value: cell_output.capacity, contract_id: dao_contract.id, block_timestamp: ckb_transaction.block_timestamp)
        if address.dao_deposit.zero? && !new_dao_depositor_events.key?(address.id)
          new_dao_depositor_events[address.id] = ckb_transaction.tx_hash
        end
      end
    end

    def build_withdraw_dao_events(address_id, ckb_transaction_id, local_block, previous_cell_output)
      if previous_cell_output.nervos_dao_withdrawing?
        withdraw_amount = previous_cell_output.capacity
        ckb_transaction = CkbTransaction.find(ckb_transaction_id)
        ckb_transaction.dao_events.create!(block: local_block, block_timestamp: local_block.timestamp,
                                           address_id: address_id, event_type: "withdraw_from_dao", value: withdraw_amount, contract_id: DaoContract.default_contract.id)
        interest = CkbUtils.dao_interest(previous_cell_output)
        ckb_transaction.dao_events.create!(block: local_block, block_timestamp: local_block.timestamp,
                                           address_id: address_id, event_type: "issue_interest", value: interest, contract_id: DaoContract.default_contract.id)
        address = Address.find(address_id)
        if (address.dao_deposit - withdraw_amount).zero?
          ckb_transaction.dao_events.create!(block: local_block, block_timestamp: local_block.timestamp,
                                             address_id: address_id, event_type: "take_away_all_deposit", value: 1, contract_id: DaoContract.default_contract.id)
        end
      end
    end

    def build_cell_output(ckb_transaction, output, address, cell_index, output_data)
      cell_output = ckb_transaction.cell_outputs.build(
        capacity: output.capacity,
        data: output_data,
        data_size: CKB::Utils.hex_to_bin(output_data).bytesize,
        occupied_capacity: CkbUtils.calculate_cell_min_capacity(output, output_data),
        address: address,
        block: ckb_transaction.block,
        tx_hash: ckb_transaction.tx_hash,
        cell_index: cell_index,
        cell_type: CkbUtils.cell_type(output.type, output_data),
        block_timestamp: ckb_transaction.block_timestamp,
        type_hash: output.type&.compute_hash,
        dao: ckb_transaction.block.dao
      )

      cell_output.udt_amount = CkbUtils.parse_udt_cell_data(output_data) if cell_output.udt?
      cell_output.udt_amount = "0x#{output.type.args[-8..-1]}".hex if cell_output.m_nft_token?

      cell_output
    end

    def build_lock_script(cell_output, lock_script, address)
      cell_output.build_lock_script(
        args: lock_script.args,
        code_hash: lock_script.code_hash,
        address: address,
        hash_type: lock_script.hash_type
      )
    end

    def build_type_script(cell_output, type_script)
      return if type_script.blank?

      cell_output.build_type_script(
        args: type_script.args,
        code_hash: type_script.code_hash,
        hash_type: type_script.hash_type
      )
    end

    def update_tx_fee_related_data(local_block, input_capacities, udt_infos)
      local_block.cell_inputs.where(from_cell_base: false,
                                    previous_cell_output_id: nil).find_in_batches(batch_size: 3500) do |cell_inputs|
        updated_inputs = []
        updated_outputs = []
        updated_ckb_transactions = []
        account_books = []
        ApplicationRecord.transaction do
          cell_inputs.each do |cell_input|
            consumed_tx = cell_input.ckb_transaction
            ckb_transaction_id = consumed_tx.id
            previous_cell_output = cell_input.previous_cell_output
            address_id = previous_cell_output.address_id
            input_capacities[ckb_transaction_id] << previous_cell_output.capacity
            if previous_cell_output.udt?
              udt_infos << {
                type_script: previous_cell_output.node_output.type, address: previous_cell_output.address,
                udt_type: "sudt" }
            end
            if previous_cell_output.m_nft_token?
              udt_infos << {
                type_script: previous_cell_output.node_output.type, address: previous_cell_output.address,
                udt_type: "m_nft_token" }
            end

            link_previous_cell_output_to_cell_input(cell_input, previous_cell_output)
            update_previous_cell_output_status(ckb_transaction_id, previous_cell_output, consumed_tx.block_timestamp)
            account_book = link_payer_address_to_ckb_transaction(ckb_transaction_id, address_id)
            update_ckb_transaction(consumed_tx, address_id, previous_cell_output, updated_ckb_transactions)
            build_withdraw_dao_events(address_id, ckb_transaction_id, local_block, previous_cell_output)

            updated_inputs << cell_input
            updated_outputs << previous_cell_output
            account_books << account_book
          end

          udt_counts_value = udt_counts_value(updated_ckb_transactions)

          dao_tx_count = updated_ckb_transactions.select { |tx| tx[:tags].include?("dao") }.count
          DaoContract.default_contract.increment!(:ckb_transactions_count, dao_tx_count)

          CellInput.import!(updated_inputs, validate: false, on_duplicate_key_update: [:previous_cell_output_id])
          CellOutput.import!(updated_outputs, validate: false,
                                              on_duplicate_key_update: [:consumed_by_id, :status, :consumed_block_timestamp])
          AccountBook.import!(account_books, validate: false)
          CkbTransaction.upsert_all(updated_ckb_transactions.uniq { |tx| tx[:id] })
          Udt.upsert_all(udt_counts_value) if udt_counts_value.present?
        end
        input_cache_keys = updated_inputs.map(&:cache_keys)
        output_cache_keys = updated_outputs.map(&:cache_keys)

        flush_caches(input_cache_keys + output_cache_keys)
      end
    end

    def udt_counts_value(updated_ckb_transactions)
      udt_ids = updated_ckb_transactions.pluck(:contained_udt_ids).flatten
      udt_counts = udt_ids.each_with_object(Hash.new(0)) { |udt_id, counts| counts[udt_id] += 1 }
      udt_counts.map do |udt_id, count|
        udt = Udt.find(udt_id)
        {
          id: udt_id, ckb_transactions_count: udt.ckb_transactions_count + count, created_at: udt.created_at,
          updated_at: Time.current }
      end
    end

    def flush_caches(cache_keys)
      cache_keys.each_slice(400) do |keys|
        $redis.pipelined do
          $redis.del(*keys)
        end
      end
    end

    def link_previous_cell_output_to_cell_input(cell_input, previous_cell_output)
      cell_input.previous_cell_output_id = previous_cell_output.id
    end

    def link_payer_address_to_ckb_transaction(ckb_transaction_id, address_id)
      { ckb_transaction_id: ckb_transaction_id, address_id: address_id }
    end

    def update_ckb_transaction(consumed_tx, address_id, previous_cell_output, updated_ckb_transactions)
      tx = updated_ckb_transactions.select { |tx| tx[:id] == consumed_tx.id }.first
      consumed_tx.contained_address_ids << address_id
      if previous_cell_output.udt?
        consumed_tx.tags << "udt"
        consumed_tx.contained_udt_ids << Udt.find_or_create_by!(type_hash: previous_cell_output.type_hash,
                                                                udt_type: "sudt").id
        consumed_tx.udt_address_ids << previous_cell_output.address_id
      end
      if previous_cell_output.nervos_dao_withdrawing?
        consumed_tx.tags << "dao"
        consumed_tx.dao_address_ids << previous_cell_output.address_id
      end
      if tx.present?
        tx[:contained_address_ids] = (tx[:contained_address_ids] << consumed_tx.contained_address_ids).flatten.uniq
        tx[:tags] = (tx[:tags] << consumed_tx.tags).flatten.uniq
        tx[:contained_udt_ids] = (tx[:contained_udt_ids] << consumed_tx.contained_udt_ids).flatten.uniq
      else
        updated_ckb_transactions << {
          id: consumed_tx.id, dao_address_ids: consumed_tx.dao_address_ids.uniq,
          udt_address_ids: consumed_tx.udt_address_ids.uniq, contained_udt_ids: consumed_tx.contained_udt_ids.uniq, contained_address_ids: consumed_tx.contained_address_ids.uniq, tags: consumed_tx.tags.uniq, created_at: consumed_tx.created_at, updated_at: Time.current }
      end
    end

    def update_previous_cell_output_status(ckb_transaction_id, previous_cell_output, consumed_block_timestamp)
      previous_cell_output.consumed_by_id = ckb_transaction_id
      previous_cell_output.consumed_block_timestamp = consumed_block_timestamp
      previous_cell_output.status = "dead"
    end

    def update_address_balance_and_ckb_transactions_count(address)
      address.balance = address.cell_outputs.live.sum(:capacity)
      address.ckb_transactions_count = address.custom_ckb_transactions.count
      address.live_cells_count = address.cell_outputs.live.count
      address.dao_transactions_count = address.ckb_dao_transactions.count
      address.save!
    end

    def calculate_tx_fee(local_block, ckb_transactions, input_capacities, outputs)
      output_capacities = outputs.each { |k, v| outputs[k] = v.map(&:capacity) }
      ckb_transactions = ckb_transactions.reject(&:is_cellbase)
      return if ckb_transactions.blank?

      txs = []
      ckb_transactions.each do |ckb_transaction|
        update_transaction_fee(ckb_transaction, input_capacities[ckb_transaction.id].sum,
                               output_capacities[ckb_transaction.id].sum)
        ckb_transaction.capacity_involved = input_capacities[ckb_transaction.id].sum unless ckb_transaction.is_cellbase
        txs << ckb_transaction
      end

      CkbTransaction.import!(txs, validate: false, on_duplicate_key_update: [:transaction_fee, :capacity_involved])
      local_block.total_transaction_fee = local_block.ckb_transactions.sum(:transaction_fee)
      local_block.save!
    rescue ActiveRecord::RecordInvalid
      local_block.update(total_transaction_fee: 0)
      Rails.logger.error "block number: #{local_block.number}, tx_fee is negative"
    end

    def update_transaction_fee(ckb_transaction, input_capacities, output_capacities)
      transaction_fee = CkbUtils.ckb_transaction_fee(ckb_transaction, input_capacities, output_capacities)
      Rails.logger.error "ckb_transaction_id: #{ckb_transaction.id}, tx_fee is negative" if transaction_fee < 0

      ckb_transaction.transaction_fee = [transaction_fee, 0].max
    end

    def update_current_block_mining_info(block)
      CkbUtils.update_current_block_mining_info(block)
    end
  end
end
