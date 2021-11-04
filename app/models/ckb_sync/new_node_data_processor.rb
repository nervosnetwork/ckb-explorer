require "benchmark_methods"

module CkbSync
  class NewNodeDataProcessor
    include BenchmarkMethods
    benchmark :call, :process_block, :build_block!, :build_uncle_blocks!, :build_ckb_transactions!, :build_udts!, :process_ckb_txs, :build_cells_and_locks!,
              :update_ckb_txs_rel_and_fee, :update_block_info!, :update_block_reward_info!, :update_mining_info, :update_table_records_count,
              :update_or_create_udt_accounts!, :update_pool_tx_status, :update_udt_info, :process_dao_events!, :update_addresses_info,
              :cache_address_txs, :generate_tx_display_info, :remove_tx_display_infos, :flush_inputs_outputs_caches, :generate_statistics_data


    def initialize
      @local_cache = LocalCache.new
    end

    def call
      local_tip_block = Block.recent.first
      tip_block_number = CkbSync::Api.instance.get_tip_block_number
      target_block_number = local_tip_block.present? ? local_tip_block.number + 1 : 0
      return if target_block_number > tip_block_number

      target_block = CkbSync::Api.instance.get_block_by_number(target_block_number)
      if !forked?(target_block, local_tip_block)
        Rails.logger.error "process_block: #{target_block_number}"
        process_block(target_block)
      else
        invalid_block(local_tip_block)
      end
    end

    def process_block(node_block)
      local_block = nil
      ApplicationRecord.transaction do
        # build node data
        local_block = build_block!(node_block)
        local_cache.write("BlockNumber", local_block.number)
        build_uncle_blocks!(node_block, local_block.id)
        inputs = []
        outputs = []
        outputs_data = []

        ckb_txs = build_ckb_transactions!(node_block, local_block, inputs, outputs, outputs_data).to_a
        build_udts!(local_block, outputs, outputs_data.flatten)

        tags = []
        udt_address_ids = []
        dao_address_ids = []
        contained_udt_ids = []
        contained_address_ids = []
        process_ckb_txs(ckb_txs, contained_address_ids, contained_udt_ids, dao_address_ids, tags, udt_address_ids)
        addrs_changes = Hash.new { |hash, key| hash[key] = {} }
        input_capacities, output_capacities = build_cells_and_locks!(local_block, node_block, ckb_txs, inputs, outputs, tags, udt_address_ids, dao_address_ids, contained_udt_ids, contained_address_ids, addrs_changes)

        # update explorer data
        update_ckb_txs_rel_and_fee(ckb_txs, tags, input_capacities, output_capacities, udt_address_ids, dao_address_ids, contained_udt_ids, contained_address_ids)
        update_block_info!(local_block)
        update_block_reward_info!(local_block)
        update_mining_info(local_block)
        update_table_records_count(local_block)
        update_or_create_udt_accounts!(local_block)
        update_pool_tx_status(local_block)
        # maybe can be changed to asynchronous update
        update_udt_info(local_block)
        process_dao_events!(local_block)
        update_addresses_info(addrs_changes)
      end

      cache_address_txs(local_block)
      generate_tx_display_info(local_block)
      remove_tx_display_infos(local_block)
      flush_inputs_outputs_caches(local_block)
      generate_statistics_data(local_block)

      local_block
    end

    private

    def generate_statistics_data(local_block)
      GenerateStatisticsDataWorker.perform_async(local_block.id)
    end

    def process_ckb_txs(ckb_txs, contained_address_ids, contained_udt_ids, dao_address_ids, tags, udt_address_ids)
      tx_index = 0
      ckb_txs.each do |cbk_tx|
        cbk_tx["tx_hash"][0] = "0"
        tags[tx_index] = Set.new
        udt_address_ids[tx_index] = Set.new
        dao_address_ids[tx_index] = Set.new
        contained_udt_ids[tx_index] = Set.new
        contained_address_ids[tx_index] = Set.new
        tx_index += 1
      end
      ckb_txs.sort! { |tx1, tx2| tx1["id"] <=> tx2["id"] }
    end

    attr_accessor :local_cache

    def flush_inputs_outputs_caches(local_block)
      FlushInputsOutputsCacheWorker.perform_async(local_block.id)
    end

    def remove_tx_display_infos(local_block)
      RemoveTxDisplayInfoWorker.perform_async(local_block.id)
    end

    def cache_address_txs(local_block)
      AddressTxsCacheUpdateWorker.perform_async(local_block.id)
    end

    def generate_tx_display_info(local_block)
      enabled = Rails.cache.read("enable_generate_tx_display_info")
      if enabled
        TxDisplayInfoGeneratorWorker.perform_async(local_block.ckb_transactions.pluck(:id))
      end
    end

    def increase_records_count(local_block)
      block_counter = TableRecordCount.find_by(table_name: "blocks")
      block_counter.increment!(:count)
      ckb_transaction_counter = TableRecordCount.find_by(table_name: "ckb_transactions")
      normal_transactions = local_block.ckb_transactions.normal.count
      ckb_transaction_counter.increment!(:count, normal_transactions.count) if normal_transactions.present?
    end

    def process_dao_events!(local_block)
      new_dao_depositors = {}
      dao_contract = DaoContract.default_contract
      process_deposit_dao_events!(local_block, new_dao_depositors, dao_contract)
      process_withdraw_dao_events!(local_block, dao_contract)
      build_new_dao_depositor_events!(local_block, new_dao_depositors, dao_contract)

      # update dao contract ckb_transactions_count
      dao_contract.increment!(:ckb_transactions_count, local_block.ckb_transactions.where("tags @> array[?]::varchar[]", ["dao"]).count)
    end

    def build_new_dao_depositor_events!(local_block, new_dao_depositors, dao_contract)
      new_dao_events_attributes = []
      new_dao_depositors.each do |address_id, ckb_transaction_id|
        new_dao_events_attributes << {
          block_id: local_block.id, ckb_transaction_id: ckb_transaction_id, address_id: address_id, event_type: "new_dao_depositor",
          value: 1, status: "processed", contract_id: dao_contract.id, block_timestamp: local_block.timestamp, created_at: Time.current,
          updated_at: Time.current }
      end

      if new_dao_events_attributes.present?
        DaoEvent.insert_all!(new_dao_events_attributes)
        dao_contract.update!(total_depositors_count: dao_contract.total_depositors_count + new_dao_events_attributes.size, depositors_count: dao_contract.depositors_count + new_dao_events_attributes.size)
        address_ids = []
        new_dao_events_attributes.each do |dao_event_attr|
          address_ids << dao_event_attr[:address_id]
        end
        Address.where(id: address_ids).update_all(is_depositor: true)
      end
    end

    def process_withdraw_dao_events!(local_block, dao_contract)
      withdraw_amount = 0
      withdraw_transaction_ids = Set.new
      addrs_withdraw_info = {}
      claimed_compensation = 0
      take_away_all_deposit_count = 0
      local_block.cell_inputs.nervos_dao_withdrawing.select(:id, :ckb_transaction_id, :previous_cell_output_id).find_in_batches do |dao_inputs|
        dao_events_attributes = []
        dao_inputs.each do |dao_input|
          previous_cell_output = CellOutput.where(id: dao_input.previous_cell_output_id).select(:address_id, :generated_by_id, :address_id, :dao, :cell_index, :capacity, :occupied_capacity).take!
          address = previous_cell_output.address
          interest = CkbUtils.dao_interest(previous_cell_output)
          if addrs_withdraw_info.key?(address.id)
            addrs_withdraw_info[address.id][:dao_deposit] -= previous_cell_output.capacity
            addrs_withdraw_info[address.id][:interest] += interest
          else
            addrs_withdraw_info[address.id] = { dao_deposit: address.dao_deposit - previous_cell_output.capacity, interest: address.interest + interest, is_depositor: address.is_depositor, created_at: address.created_at }
          end
          dao_events_attributes << {
            ckb_transaction_id: dao_input.ckb_transaction_id, block_id: local_block.id, block_timestamp: local_block.timestamp, address_id: previous_cell_output.address_id, event_type: "withdraw_from_dao", value: previous_cell_output.capacity, status: "processed", contract_id: dao_contract.id, created_at: Time.current,
            updated_at: Time.current }
          dao_events_attributes << {
            ckb_transaction_id: dao_input.ckb_transaction_id, block_id: local_block.id, block_timestamp: local_block.timestamp, address_id: previous_cell_output.address_id, event_type: "issue_interest", value: interest, status: "processed", contract_id: dao_contract.id, created_at: Time.current,
            updated_at: Time.current }
          address_dao_deposit = Address.where(id: previous_cell_output.address_id).pick(:dao_deposit)
          if (address_dao_deposit - previous_cell_output.capacity).zero?
            take_away_all_deposit_count += 1
            addrs_withdraw_info[address.id][:is_depositor] = false
            dao_events_attributes << {
              ckb_transaction_id: dao_input.ckb_transaction_id, block_id: local_block.id, block_timestamp: local_block.timestamp, address_id: previous_cell_output.address_id, event_type: "take_away_all_deposit", value: 1, status: "processed", contract_id: dao_contract.id, created_at: Time.current,
              updated_at: Time.current }
          end
          withdraw_amount += previous_cell_output.capacity
          claimed_compensation += interest
          withdraw_transaction_ids << dao_input.ckb_transaction_id
        end
        DaoEvent.insert_all!(dao_events_attributes) if dao_events_attributes.present?
      end
      # update dao contract info
      dao_contract.update!(total_deposit: dao_contract.total_deposit - withdraw_amount, withdraw_transactions_count: dao_contract.withdraw_transactions_count + withdraw_transaction_ids.size, claimed_compensation: dao_contract.claimed_compensation + claimed_compensation, depositors_count: dao_contract.depositors_count - take_away_all_deposit_count)
      update_addresses_dao_info(addrs_withdraw_info)
    end

    def process_deposit_dao_events!(local_block, new_dao_depositors, dao_contract)
      deposit_amount = 0
      deposit_transaction_ids = Set.new
      addresses_deposit_info = {}
      # build deposit dao events
      local_block.cell_outputs.nervos_dao_deposit.select(:id, :address_id, :capacity, :ckb_transaction_id).find_in_batches do |dao_outputs|
        deposit_dao_events_attributes = []
        dao_outputs.each do |dao_output|
          address = dao_output.address
          if addresses_deposit_info.key?(address.id)
            addresses_deposit_info[address.id][:dao_deposit] += dao_output.capacity
          else
            addresses_deposit_info[address.id] = { dao_deposit: address.dao_deposit + dao_output.capacity, interest: address.interest, is_depositor: address.is_depositor, created_at: address.created_at }
          end
          if address.dao_deposit.zero? && !new_dao_depositors.key?(address.id)
            new_dao_depositors[address.id] = dao_output.ckb_transaction_id
          end
          deposit_amount += dao_output.capacity
          deposit_transaction_ids << dao_output.ckb_transaction_id
          deposit_dao_events_attributes << {
            ckb_transaction_id: dao_output.ckb_transaction_id, block_id: local_block.id, address_id: address.id, event_type: "deposit_to_dao",
            value: dao_output.capacity, status: "processed", contract_id: dao_contract.id, block_timestamp: local_block.timestamp, created_at: Time.current,
            updated_at: Time.current }
        end
        DaoEvent.insert_all!(deposit_dao_events_attributes) if deposit_dao_events_attributes.present?
      end
      # update dao contract info
      dao_contract.update!(total_deposit: dao_contract.total_deposit + deposit_amount, deposit_transactions_count: dao_contract.deposit_transactions_count + deposit_transaction_ids.size)
      update_addresses_dao_info(addresses_deposit_info)
    end

    def update_addresses_dao_info(addrs_deposit_info)
      addresses_deposit_attributes = []
      addrs_deposit_info.each do |address_id, address_info|
        addresses_deposit_attributes << { id: address_id, dao_deposit: address_info[:dao_deposit], interest: address_info[:interest], created_at: address_info[:created_at], updated_at: Time.current }
      end
      Address.upsert_all(addresses_deposit_attributes) if addresses_deposit_attributes.present?
    end

    def update_pool_tx_status(local_block)
      PoolTransactionEntry.pool_transaction_pending.where(tx_hash: local_block.ckb_transactions.pluck(:tx_hash)).update_all(tx_status: "committed")
    end

    def update_udt_info(local_block)
      type_hashes = []
      local_block.cell_outputs.udt.select(:id, :type_hash).find_each do |udt_output|
        type_hashes << udt_output.type_hash
      end
      CellOutput.where(consumed_by_id: local_block.ckb_transactions.pluck(:id)).udt.select(:id, :type_hash).find_each do |udt_output|
        type_hashes << udt_output.type_hash
      end
      return if type_hashes.blank?

      amount_info = UdtAccount.where(type_hash: type_hashes).group(:type_hash).sum(:amount)
      addresses_count_info = UdtAccount.where(type_hash: type_hashes).group(:type_hash).count(:address_id)
      udts_attributes = Set.new
      type_hashes.each do |type_hash|
        udt = Udt.where(type_hash: type_hash).select(:id).take!
        udts_attributes << { type_hash: type_hash, total_amount: amount_info[type_hash], addresses_count: addresses_count_info[type_hash], ckb_transactions_count: udt.ckb_transactions.count }
      end

      Udt.upsert_all(udts_attributes.map! { |attr| attr.merge!(created_at: Time.current, updated_at: Time.current) }, unique_by: :type_hash) if udts_attributes.present?
    end

    def update_or_create_udt_accounts!(local_block)
      new_udt_accounts_attributes = Set.new
      udt_accounts_attributes = Set.new
      local_block.cell_outputs.where(cell_type: %w(udt m_nft_token)).select(:id, :address_id, :type_hash, :cell_type).find_each do |udt_output|
        address = Address.find(udt_output.address_id)
        udt_type = udt_type(udt_output.cell_type)
        udt_account = address.udt_accounts.where(type_hash: udt_output.type_hash, udt_type: udt_type).select(:id, :created_at).first
        amount = udt_account_amount(udt_type, udt_output.type_hash, address)
        udt = Udt.where(type_hash: udt_output.type_hash, udt_type: udt_type).select(:id, :udt_type, :full_name, :symbol, :decimal, :published, :code_hash, :type_hash, :created_at).take!
        if udt_account.present?
          udt_accounts_attributes << { id: udt_account.id, amount: amount, created_at: udt.created_at }
        else
          new_udt_accounts_attributes << {
            address_id: udt_output.address_id, udt_type: udt.udt_type, full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal,
            published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount, udt_id: udt.id }
        end
      end

      CellOutput.where(consumed_by_id: local_block.ckb_transactions.pluck(:id)).where(cell_type: %w(udt m_nft_token)).select(:id, :address_id, :type_hash, :cell_type).find_each do |udt_output|
        address = Address.find(udt_output.address_id)
        udt_type = udt_type(udt_output.cell_type)
        udt_account = address.udt_accounts.where(type_hash: udt_output.type_hash, udt_type: udt_type).select(:id, :created_at).first
        amount = udt_account_amount(udt_type, udt_output.type_hash, address)
        udt = Udt.where(type_hash: udt_output.type_hash, udt_type: udt_type).select(:id, :udt_type, :full_name, :symbol, :decimal, :published, :code_hash, :type_hash, :created_at).take!
        if udt_account.present?
          case udt_type
          when "sudt"
            udt_accounts_attributes << { id: udt_account.id, amount: amount, created_at: udt.created_at }
          when "m_nft_token"
            udt_account.destroy unless address.cell_outputs.live.m_nft_token.where(type_hash: udt_output.type_hash).exists?
          end
        end
      end

      UdtAccount.insert_all!(new_udt_accounts_attributes.map! { |attr| attr.merge!(created_at: Time.current, updated_at: Time.current) }) if new_udt_accounts_attributes.present?
      UdtAccount.upsert_all(udt_accounts_attributes.map! { |attr| attr.merge!(updated_at: Time.current) }) if udt_accounts_attributes.present?
    end

    def udt_type(cell_type)
      cell_type == "udt" ? "sudt" : cell_type
    end

    def udt_account_amount(udt_type, type_hash, address)
      case udt_type
      when "sudt"
        address.cell_outputs.live.udt.where(type_hash: type_hash).sum(:udt_amount)
      when "m_nft_token"
        address.cell_outputs.live.m_nft_token.where(type_hash: type_hash).sum(:udt_amount)
      else
        0
      end
    end

    def update_table_records_count(local_block)
      block_counter = TableRecordCount.find_by(table_name: "blocks")
      block_counter.increment!(:count)
      ckb_transaction_counter = TableRecordCount.find_by(table_name: "ckb_transactions")
      normal_transactions = local_block.ckb_transactions.normal
      ckb_transaction_counter.increment!(:count, normal_transactions.count) if normal_transactions.present?
    end

    def update_block_reward_info!(local_block)
      target_block_number = local_block.target_block_number
      target_block = local_block.target_block
      return if target_block_number < 1 || target_block.blank?

      issue_block_reward!(local_block)
    end

    def issue_block_reward!(current_block)
      CkbUtils.update_block_reward!(current_block)
      CkbUtils.calculate_received_tx_fee!(current_block)
    end

    def update_mining_info(local_block)
      CkbUtils.update_current_block_mining_info(local_block)
    end

    def update_addresses_info(addrs_change)
      addrs = []
      attributes = addrs_change.map do |addr_id, values|
        addr = Address.where(id: addr_id).select(:id, :address_hash, :lock_hash, :balance, :ckb_transactions_count, :dao_transactions_count, :live_cells_count, :created_at, :balance_occupied).take!
        balance_diff = values[:balance_diff]
        balance_occupied_diff = values[:balance_occupied_diff].presence || 0
        live_cells_diff = values[:cells_diff]
        dao_txs_count = values[:dao_txs].present? ? values[:dao_txs].size : 0
        ckb_txs_count = values[:ckb_txs].present? ? values[:ckb_txs].size : 0
        addrs << addr
        { id: addr.id, balance: addr.balance + balance_diff, balance_occupied: addr.balance_occupied + balance_occupied_diff, ckb_transactions_count: addr.ckb_transactions_count + ckb_txs_count,
          live_cells_count: addr.live_cells_count + live_cells_diff, dao_transactions_count: addr.dao_transactions_count + dao_txs_count, created_at: addr.created_at, updated_at: Time.current }
      end
      if attributes.present?
        Address.upsert_all(attributes)
        addrs.each(&:touch)
      end
    end

    def update_block_info!(local_block)
      local_block.update!(total_transaction_fee: local_block.ckb_transactions.sum(:transaction_fee),
                          ckb_transactions_count: local_block.ckb_transactions.count,
                          live_cell_changes: local_block.ckb_transactions.sum(&:live_cell_changes),
                          address_ids: local_block.ckb_transactions.pluck(:contained_address_ids).flatten.uniq)
    end

    def build_udts!(local_block, outputs, outputs_data)
      udts_attributes = Set.new
      outputs.each_with_index do |output, index|
        next if output.is_a?(Integer)

        cell_type = cell_type(output.type, outputs_data[index])
        next unless cell_type.in?(%w(udt m_nft_token))

        type_hash = output.type.compute_hash
        unless Udt.where(type_hash: type_hash).exists?
          m_nft_token_attr = { full_name: nil, icon_file: nil, published: false }
          if cell_type == "m_nft_token"
            m_nft_class_type = TypeScript.where(code_hash: CkbSync::Api.instance.token_class_script_code_hash, args: output.type.args[0..49]).first
            if m_nft_class_type.present?
              m_nft_class_cell = m_nft_class_type.cell_outputs.last
              parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
              m_nft_token_attr[:full_name] = parsed_class_data.name
              m_nft_token_attr[:icon_file] = parsed_class_data.renderer
              m_nft_token_attr[:published] = true
            end
          end
          # fill issuer_address after publish the token
          udts_attributes << {
            type_hash: type_hash, udt_type: udt_type(cell_type), block_timestamp: local_block.timestamp, args: output.type.args,
            code_hash: output.type.code_hash, hash_type: output.type.hash_type }.merge(m_nft_token_attr)
        end
      end
      Udt.insert_all!(udts_attributes.map! { |attr| attr.merge!(created_at: Time.current, updated_at: Time.current) }) if udts_attributes.present?
    end

    def update_ckb_txs_rel_and_fee(ckb_txs, tags, input_capacities, output_capacities, udt_address_ids, dao_address_ids, contained_udt_ids, contained_addr_ids)
      ckb_transactions_attributes = []
      tx_index = 0
      ckb_txs.each do |tx|
        if tx_index == 0
          ckb_transactions_attributes << {
            id: tx["id"], dao_address_ids: dao_address_ids[tx_index].to_a,
            udt_address_ids: udt_address_ids[tx_index].to_a, contained_udt_ids: contained_udt_ids[tx_index].to_a,
            contained_address_ids: contained_addr_ids[tx_index].to_a, tags: tags[tx_index].to_a,
            capacity_involved: input_capacities[tx_index], transaction_fee: 0,
            created_at: tx["created_at"], updated_at: Time.current }
        else
          ckb_transactions_attributes << {
            id: tx["id"], dao_address_ids: dao_address_ids[tx_index].to_a,
            udt_address_ids: udt_address_ids[tx_index].to_a, contained_udt_ids: contained_udt_ids[tx_index].to_a,
            contained_address_ids: contained_addr_ids[tx_index].to_a, tags: tags[tx_index].to_a,
            capacity_involved: input_capacities[tx_index], transaction_fee: CkbUtils.ckb_transaction_fee(tx, input_capacities[tx_index], output_capacities[tx_index]),
            created_at: tx["created_at"], updated_at: Time.current }
        end
        tx_index += 1
      end

      CkbTransaction.upsert_all(ckb_transactions_attributes) if ckb_transactions_attributes.present?
    end

    def build_cells_and_locks!(local_block, node_block, ckb_txs, inputs, outputs, tags, udt_address_ids, dao_address_ids, contained_udt_ids, contained_addr_ids, addrs_changes)
      cell_outputs_attributes = []
      cell_inputs_attributes = []
      prev_cell_outputs_attributes = []
      input_capacities = []
      output_capacities = []
      lock_scripts_attributes, type_scripts_attributes = build_scripts(outputs)
      if lock_scripts_attributes.present?
        lock_scripts_attributes.map! { |attr| attr.merge!(created_at: Time.current, updated_at: Time.current) }
        LockScript.insert_all!(lock_scripts_attributes)
      end
      if type_scripts_attributes.present?
        type_scripts_attributes.map! { |attr| attr.merge!(created_at: Time.current, updated_at: Time.current) }
        TypeScript.insert_all!(type_scripts_attributes)
      end
      build_addresses!(outputs, local_block)
      # prepare script ids for insert cell_outputs
      prepare_script_ids(outputs)
      build_cell_outputs!(node_block, outputs, ckb_txs, local_block, cell_outputs_attributes, output_capacities, tags, udt_address_ids, dao_address_ids, contained_udt_ids, contained_addr_ids, addrs_changes)

      CellOutput.insert_all!(cell_outputs_attributes) if cell_outputs_attributes.present?
      prev_outputs = prepare_previous_outputs(inputs)
      build_cell_inputs(inputs, ckb_txs, local_block.id, cell_inputs_attributes, prev_cell_outputs_attributes, input_capacities, tags, udt_address_ids, dao_address_ids, contained_udt_ids, contained_addr_ids, prev_outputs, addrs_changes)

      CellInput.insert_all!(cell_inputs_attributes)
      CellOutput.upsert_all(prev_cell_outputs_attributes) if prev_cell_outputs_attributes.present?
      return input_capacities, output_capacities
    end

    def prepare_previous_outputs(inputs)
      previous_outputs = {}
      outpoints = []
      sql = "select id, tx_hash, cell_index, cell_type, capacity, address_id, type_hash, created_at, data from cell_outputs where "
      inputs.each do |item|
        if !item.is_a?(Integer) && !from_cell_base?(item)
          outpoints << "(tx_hash = '\\#{item.previous_output.tx_hash.delete_prefix('0')}' and cell_index = #{item.previous_output.index}) or "
        end
      end
      block_number = local_cache.read("BlockNumber")
      # not just cellbase in inputs
      if inputs.size > 2
        outpoints.each_slice(100) do |ops|
          inner_sql = sql.dup
          ops.each do |op|
            inner_sql << op
          end
          inner_sql.delete_suffix!("or ")
          CellOutput.find_by_sql(inner_sql).each do |item|
            previous_outputs["#{item.tx_hash}-#{item.cell_index}"] = item
            local_cache.push("NodeData/#{block_number}/ContainedAddresses", Address.where(id: item.address_id).select(:id, :created_at).first!)
          end
        end
      end
      previous_outputs
    end

    def build_addresses!(outputs, local_block)
      block_number = local_cache.read("BlockNumber")
      outputs.each do |item|
        unless item.is_a?(Integer)
          address =
            local_cache.fetch("NodeData/Address/#{item.lock.code_hash}-#{item.lock.hash_type}-#{item.lock.args}") do
              # TODO use LockScript.where(script_hash: output.lock.compute_hash).select(:id)&.first replace search by code_hash, hash_type and args query after script_hash has been filled
              lock_script = LockScript.find_by(code_hash: item.lock.code_hash, hash_type: item.lock.hash_type, args: item.lock.args)
              Address.find_or_create_address(item.lock, local_block.timestamp, lock_script.id)
            end
          local_cache.push("NodeData/#{block_number}/ContainedAddresses", Address.new(id: address.id, created_at: address.created_at))
        end
      end
    end

    def prepare_script_ids(outputs)
      outputs.each do |output|
        unless output.is_a?(Integer)
          local_cache.fetch("NodeData/LockScript/#{output.lock.code_hash}-#{output.lock.hash_type}-#{output.lock.args}") do
            # TODO use LockScript.where(script_hash: output.lock.compute_hash).select(:id)&.first replace search by code_hash, hash_type and args query after script_hash has been filled
            LockScript.where(code_hash: output.lock.code_hash, hash_type: output.lock.hash_type, args: output.lock.args).select(:id).take!
          end
          if output.type.present?
            local_cache.fetch("NodeData/TypeScript/#{output.type.code_hash}-#{output.type.hash_type}-#{output.type.args}") do
              # TODO use TypeScript.where(script_hash: output.type.compute_hash).select(:id)&.first replace search by code_hash, hash_type and args query after script_hash has been filled
              TypeScript.where(code_hash: output.type.code_hash, hash_type: output.type.hash_type, args: output.type.args).select(:id).take!
            end
          end
        end
      end
    end

    def build_scripts(outputs)
      locks_attributes = Set.new
      types_attributes = Set.new
      block_number = local_cache.read("BlockNumber")
      outputs.each do |output|
        unless output.is_a?(Integer)
          unless local_cache.read("NodeData/#{block_number}/Lock/#{output.lock.code_hash}-#{output.lock.hash_type}-#{output.lock.args}")
            script_hash = output.lock.compute_hash
            # TODO use LockScript.where(script_hash: script_hash).exists? replace search by code_hash, hash_type and args query after script_hash has been filled
            unless LockScript.where(code_hash: output.lock.code_hash, hash_type: output.lock.hash_type, args: output.lock.args).exists?
              locks_attributes << script_attributes(output.lock, script_hash)
              local_cache.write("NodeData/#{block_number}/Lock/#{output.lock.code_hash}-#{output.lock.hash_type}-#{output.lock.args}", true)
            end
          end
          if output.type.present? && !local_cache.read("NodeData/#{block_number}/Type/#{output.type.code_hash}-#{output.type.hash_type}-#{output.type.args}")
            script_hash = output.type.compute_hash
            # TODO use TypeScript.where(script_hash: script_hash).exists? replace search by code_hash, hash_type and args query after script_hash has been filled
            unless TypeScript.where(code_hash: output.type.code_hash, hash_type: output.type.hash_type, args: output.type.args).exists?
              types_attributes << script_attributes(output.type, script_hash)
              local_cache.write("NodeData/#{block_number}/Type/#{output.type.code_hash}-#{output.type.hash_type}-#{output.type.args}", true)
            end
          end
        end
      end

      return locks_attributes.to_a.compact, types_attributes.to_a.compact
    end

    def script_attributes(script, script_hash)
      {
        args: script.args,
        code_hash: script.code_hash,
        hash_type: script.hash_type,
        script_hash: script_hash
      }
    end

    def build_cell_inputs(inputs, ckb_txs, local_block_id, cell_inputs_attributes, prev_cell_outputs_attributes, input_capacities, tags, udt_address_ids, dao_address_ids, contained_udt_ids, contained_addr_ids, prev_outputs, addrs_changes)
      tx_index = 0
      inputs.each do |item|
        if item.is_a?(Integer)
          tx_index = item
          input_capacities[tx_index] = 0 if item != 0
        else
          # attributes[0] is cell_inputs_attributes
          # attributes[1] is prev_cell_outputs_attributes
          # attributes[2] is previous_cell_output capacity
          # attributes[3] is previous_cell_output type_hash
          # attributes[4] is previous_cell address_id
          # attributes[5] is previous_cell data
          attributes = cell_input_attributes(item, ckb_txs[tx_index]["id"], local_block_id, prev_outputs)
          cell_inputs_attributes << attributes[0]
          if attributes[1].present?
            if addrs_changes[attributes[4]][:balance_diff].present?
              addrs_changes[attributes[4]][:balance_diff] -= attributes[2]
            else
              addrs_changes[attributes[4]][:balance_diff] = -attributes[2]
            end
            if addrs_changes[attributes[4]][:balance_occupied_diff].present?
              addrs_changes[attributes[4]][:balance_occupied_diff] -= attributes[2] if occupied?(attributes[3], attributes[5])
            else
              addrs_changes[attributes[4]][:balance_occupied_diff] = -attributes[2] if occupied?(attributes[3], attributes[5])
            end
            if addrs_changes[attributes[4]][:cells_diff].present?
              addrs_changes[attributes[4]][:cells_diff] -= 1
            else
              addrs_changes[attributes[4]][:cells_diff] = -1
            end
            if addrs_changes[attributes[4]][:ckb_txs].present?
              addrs_changes[attributes[4]][:ckb_txs] << ckb_txs[tx_index]["tx_hash"]
            else
              addrs_changes[attributes[4]][:ckb_txs] = Set.new([ckb_txs[tx_index]["tx_hash"]])
            end

            prev_cell_outputs_attributes << attributes[1]
            contained_addr_ids[tx_index] << attributes[4]
            if attributes[1][:cell_type].in?(%w(nervos_dao_withdrawing))
              tags[tx_index] << "dao"
              dao_address_ids[tx_index] << attributes[4]
              if addrs_changes[attributes[4]][:dao_txs].present?
                addrs_changes[attributes[4]][:dao_txs] << ckb_txs[tx_index]["tx_hash"]
              else
                addrs_changes[attributes[4]][:dao_txs] = Set.new([ckb_txs[tx_index]["tx_hash"]])
              end
            end
            if attributes[1][:cell_type] == "udt"
              tags[tx_index] << "udt"
              udt_address_ids[tx_index] << attributes[4]
              contained_udt_ids[tx_index] << Udt.where(type_hash: attributes[3], udt_type: "sudt").pick(:id)
            end
          end
          input_capacities[tx_index] += attributes[2] if tx_index != 0 && attributes[2].present?
        end
      end
    end

    def build_cell_outputs!(node_block, outputs, ckb_txs, local_block, cell_outputs_attributes, output_capacities, tags, udt_address_ids, dao_address_ids, contained_udt_ids, contained_addr_ids, addrs_changes)
      cell_index = 0
      tx_index = 0
      outputs.each do |item|
        if item.is_a?(Integer)
          tx_index = item
          cell_index = 0
          # tx_index == 0 is cellbase, no need to calculate fee
          if tx_index != 0
            output_capacities[tx_index] = 0
          end
        else
          address = local_cache.read("NodeData/Address/#{item.lock.code_hash}-#{item.lock.hash_type}-#{item.lock.args}")
          cell_data = node_block.transactions[tx_index].outputs_data[cell_index]
          if addrs_changes[address.id][:balance_diff].present?
            addrs_changes[address.id][:balance_diff] += item.capacity
          else
            addrs_changes[address.id][:balance_diff] = item.capacity
          end
          if addrs_changes[address.id][:balance_occupied_diff].present?
            addrs_changes[address.id][:balance_occupied_diff] += item.capacity if occupied?(item.type&.compute_hash, cell_data)
          else
            addrs_changes[address.id][:balance_occupied_diff] = item.capacity if occupied?(item.type&.compute_hash, cell_data)
          end

          if addrs_changes[address.id][:cells_diff].present?
            addrs_changes[address.id][:cells_diff] += 1
          else
            addrs_changes[address.id][:cells_diff] = 1
          end
          if addrs_changes[address.id][:ckb_txs].present?
            addrs_changes[address.id][:ckb_txs] << ckb_txs[tx_index]["tx_hash"]
          else
            addrs_changes[address.id][:ckb_txs] = Set.new([ckb_txs[tx_index]["tx_hash"]])
          end
          contained_addr_ids[tx_index] << address.id
          attr = cell_output_attributes(item, address, ckb_txs[tx_index], local_block, cell_index, node_block.transactions[tx_index].outputs_data[cell_index])
          cell_outputs_attributes << attr
          if attr[:cell_type].in?(%w(nervos_dao_deposit nervos_dao_withdrawing))
            tags[tx_index] << "dao"
            dao_address_ids[tx_index] << address.id
            if addrs_changes[address.id][:dao_txs].present?
              addrs_changes[address.id][:dao_txs] << ckb_txs[tx_index]["tx_hash"]
            else
              addrs_changes[address.id][:dao_txs] = Set.new([ckb_txs[tx_index]["tx_hash"]])
            end
          end
          if attr[:cell_type] == "udt"
            tags[tx_index] << "udt"
            udt_address_ids[tx_index] << address.id
            contained_udt_ids[tx_index] << Udt.where(type_hash: item.type.compute_hash, udt_type: "sudt").pick(:id)
          end

          output_capacities[tx_index] += item.capacity if tx_index != 0
          cell_index += 1
        end
      end
    end

    def occupied?(type_hash, cell_data)
      cell_data.present? && cell_data != "0x" || type_hash.present?
    end

    def cell_output_attributes(output, address, ckb_transaction, local_block, cell_index, output_data)
      lock_script = local_cache.fetch("NodeData/LockScript/#{output.lock.code_hash}-#{output.lock.hash_type}-#{output.lock.args}")
      type_script =
        if output.type.present?
          local_cache.fetch("NodeData/TypeScript/#{output.type.code_hash}-#{output.type.hash_type}-#{output.type.args}")
        end
      udt_amount = udt_amount(cell_type(output.type, output_data), output_data, output.type&.args)
      {
        ckb_transaction_id: ckb_transaction["id"],
        capacity: output.capacity,
        data: output_data,
        data_size: 0,
        occupied_capacity: 0,
        address_id: address.id,
        block_id: local_block.id,
        tx_hash: ckb_transaction["tx_hash"],
        cell_index: cell_index,
        generated_by_id: ckb_transaction["id"],
        cell_type: cell_type(output.type, output_data),
        block_timestamp: local_block.timestamp,
        type_hash: output.type&.compute_hash,
        dao: local_block.dao,
        lock_script_id: lock_script.id,
        type_script_id: type_script&.id,
        udt_amount: udt_amount,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    def udt_amount(cell_type, output_data, type_script_args)
      case cell_type
      when "udt"
        CkbUtils.parse_udt_cell_data(output_data)
      when "m_nft_token"
        "0x#{type_script_args[-8..-1]}".hex
      end
    end

    def cell_input_attributes(input, ckb_transaction_id, local_block_id, prev_outputs)
      if from_cell_base?(input)
        [
          {
            ckb_transaction_id: ckb_transaction_id,
            previous_output: input.previous_output,
            since: input.since,
            block_id: local_block_id,
            from_cell_base: from_cell_base?(input),
            previous_cell_output_id: nil,
            cell_type: "normal",
            created_at: Time.current,
            updated_at: Time.current
          }
        ]
      else
        previous_output = prev_outputs["#{input.previous_output.tx_hash}-#{input.previous_output.index}"]
        [
          {
            ckb_transaction_id: ckb_transaction_id,
            previous_output: input.previous_output,
            since: input.since,
            block_id: local_block_id,
            from_cell_base: from_cell_base?(input),
            previous_cell_output_id: previous_output.id,
            cell_type: previous_output.cell_type,
            created_at: Time.current,
            updated_at: Time.current
          },
          {
            id: previous_output.id,
            consumed_by_id: ckb_transaction_id,
            cell_type: previous_output.cell_type,
            created_at: previous_output.created_at,
            status: "dead",
            updated_at: Time.current,
            consumed_block_timestamp: CkbTransaction.find(ckb_transaction_id).block_timestamp
          },
          previous_output.capacity,
          previous_output.type_hash,
          previous_output.address_id,
          previous_output.data
        ]
      end
    end

    def build_ckb_transactions!(node_block, local_block, inputs, outputs, outputs_data)
      ckb_transactions_attributes = []
      tx_index = 0
      node_block.transactions.each do |tx|
        ckb_transactions_attributes << ckb_transaction_attributes(local_block, tx, tx_index)
        inputs << tx_index
        inputs.concat tx.inputs
        outputs << tx_index
        outputs.concat tx.outputs
        outputs_data << tx_index
        outputs_data.concat << tx.outputs_data
        tx_index += 1

      end
      CkbTransaction.insert_all!(ckb_transactions_attributes, returning: %w(id tx_hash created_at))
    end

    def ckb_transaction_attributes(local_block, tx, tx_index)
      {
        block_id: local_block.id,
        tx_hash: tx.hash,
        cell_deps: tx.cell_deps,
        header_deps: tx.header_deps,
        version: tx.version,
        block_number: local_block.number,
        block_timestamp: local_block.timestamp,
        transaction_fee: 0,
        witnesses: tx.witnesses,
        is_cellbase: tx_index.zero?,
        live_cell_changes: live_cell_changes(tx, tx_index),
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    def build_uncle_blocks!(node_block, local_block_id)
      node_block.uncles.each do |uncle_block|
        header = uncle_block.header
        epoch_info = CkbUtils.parse_epoch_info(header)
        UncleBlock.create!(
          block_id: local_block_id,
          compact_target: header.compact_target,
          block_hash: header.hash,
          number: header.number,
          parent_hash: header.parent_hash,
          nonce: header.nonce,
          timestamp: header.timestamp,
          transactions_root: header.transactions_root,
          proposals_hash: header.proposals_hash,
          extra_hash: header.try(:uncles_hash).presence || header.try(:extra_hash),
          version: header.version,
          proposals: uncle_block.proposals,
          proposals_count: uncle_block.proposals.count,
          epoch: epoch_info.number,
          dao: header.dao
        )
      end
    end

    def build_block!(node_block)
      header = node_block.header
      epoch_info = CkbUtils.parse_epoch_info(header)
      cellbase = node_block.transactions.first

      generate_address_in_advance(cellbase, header.timestamp)
      block_cell_consumed = CkbUtils.block_cell_consumed(node_block.transactions)
      total_cell_capacity = CkbUtils.total_cell_capacity(node_block.transactions)
      miner_hash = CkbUtils.miner_hash(cellbase)
      miner_lock_hash = CkbUtils.miner_lock_hash(cellbase)
      base_reward = CkbUtils.base_reward(header.number, epoch_info.number)
      Block.create!(
        compact_target: header.compact_target,
        block_hash: header.hash,
        number: header.number,
        parent_hash: header.parent_hash,
        nonce: header.nonce,
        timestamp: header.timestamp,
        transactions_root: header.transactions_root,
        proposals_hash: header.proposals_hash,
        uncles_count: node_block.uncles.count,
        extra_hash: header.try(:uncles_hash).presence || header.try(:extra_hash),
        uncle_block_hashes: uncle_block_hashes(node_block.uncles),
        version: header.version,
        proposals: node_block.proposals,
        proposals_count: node_block.proposals.count,
        cell_consumed: block_cell_consumed,
        total_cell_capacity: total_cell_capacity,
        miner_hash: miner_hash,
        miner_lock_hash: miner_lock_hash,
        reward: base_reward,
        primary_reward: base_reward,
        secondary_reward: 0,
        reward_status: header.number.to_i == 0 ? "issued" : "pending",
        total_transaction_fee: 0,
        epoch: epoch_info.number,
        start_number: epoch_info.start_number,
        length: epoch_info.length,
        dao: header.dao,
        block_time: block_time(header.timestamp, header.number),
        block_size: 0,
        miner_message: CkbUtils.miner_message(cellbase),
        extension: node_block.extension
      )
    end

    def from_cell_base?(node_input)
      node_input.previous_output.tx_hash == CellOutput::SYSTEM_TX_HASH
    end

    def live_cell_changes(transaction, transaction_index)
      transaction_index.zero? ? 1 : transaction.outputs.count - transaction.inputs.count
    end

    def block_time(timestamp, number)
      target_block_number = [number - 1, 0].max
      return 0 if target_block_number.zero?

      previous_block_timestamp = Block.find_by(number: target_block_number).timestamp
      timestamp - previous_block_timestamp
    end

    def uncle_block_hashes(node_block_uncles)
      hashes = []
      node_block_uncles.each do |uncle|
        hashes << uncle.header.hash
      end

      hashes
    end

    def generate_address_in_advance(cellbase, block_timestamp)
      return if cellbase.witnesses.blank?

      lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
      lock = LockScript.find_or_create_by(
        code_hash: lock_script.code_hash,
        hash_type: lock_script.hash_type,
        args: lock_script.args
      )
      local_cache.fetch("NodeData/Address/#{lock_script.code_hash}-#{lock_script.hash_type}-#{lock_script.args}") do
        Address.find_or_create_address(lock_script, block_timestamp, lock.id)
      end
    end

    def cell_type(type_script, output_data = nil)
      CkbUtils.cell_type(type_script, output_data)
    end

    def forked?(target_block, local_tip_block)
      return false if local_tip_block.blank?

      target_block.header.parent_hash != local_tip_block.block_hash
    end

    def invalid_block(local_tip_block)
      ApplicationRecord.transaction do
        result =
          Benchmark.realtime do
            revert_dao_contract_related_operations(local_tip_block)
          end
        Rails.logger.error "revert_dao_contract_related_operations!: %5.3f" % result
        result =
          Benchmark.realtime do
            revert_mining_info(local_tip_block)
          end
        Rails.logger.error "revert_mining_info!: %5.3f" % result
        udt_type_hashes = nil
        result =
          Benchmark.realtime do
            udt_type_hashes = local_tip_block.cell_outputs.udt.pluck(:type_hash).uniq.concat(local_tip_block.cell_outputs.m_nft_token.pluck(:type_hash).uniq)
          end
        Rails.logger.error "pluck type_hash!: %5.3f" % result
        result =
          Benchmark.realtime do
            recalculate_udt_transactions_count(local_tip_block)
          end
        Rails.logger.error "recalculate_udt_transactions_count: %5.3f" % result
        result =
          Benchmark.realtime do
            recalculate_dao_contract_transactions_count(local_tip_block)
          end
        Rails.logger.error "recalculate_dao_contract_transactions_count: %5.3f" % result
        result =
          Benchmark.realtime do
            decrease_records_count(local_tip_block)
          end
        Rails.logger.error "decrease_records_count: %5.3f" % result
        result =
          Benchmark.realtime do
            local_tip_block.invalid!
          end
        Rails.logger.error "invalid! block: %5.3f" % result
        result =
          Benchmark.realtime do
            recalculate_udt_accounts(udt_type_hashes, local_tip_block)
          end
        Rails.logger.error "recalculate_udt_accounts: %5.3f" % result
        result =
          Benchmark.realtime do
            local_tip_block.contained_addresses.each(&method(:update_address_balance_and_ckb_transactions_count))
          end
        Rails.logger.error "update_address_balance_and_ckb_transactions_count: %5.3f" % result
        result =
          Benchmark.realtime do
            revert_block_rewards(local_tip_block)
          end
        Rails.logger.error "revert_block_rewards: %5.3f" % result
        result =
          Benchmark.realtime do
            ForkedEvent.create!(block_number: local_tip_block.number, epoch_number: local_tip_block.epoch, block_timestamp: local_tip_block.timestamp)
          end
        Rails.logger.error "ForkedEvent: %5.3f" % result
        result =
          Benchmark.realtime do
            Charts::BlockStatisticGenerator.new(local_tip_block.number).call
          end
        Rails.logger.error "BlockStatisticGenerator: %5.3f" % result
        local_tip_block
      end
    end

    def update_address_balance_and_ckb_transactions_count(address)
      address.balance = address.cell_outputs.live.sum(:capacity)
      address.ckb_transactions_count = address.custom_ckb_transactions.count
      address.live_cells_count = address.cell_outputs.live.count
      address.dao_transactions_count = address.ckb_dao_transactions.count
      address.save!
    end

    def revert_block_rewards(local_tip_block)
      target_block = local_tip_block.target_block
      target_block_number = local_tip_block.target_block_number
      return if target_block_number < 1 || target_block.blank?

      revert_reward_status(target_block)
      revert_received_tx_fee(target_block)
    end

    def revert_reward_status(target_block)
      target_block.update!(reward_status: "pending")
      target_block.update!(received_tx_fee_status: "pending")
    end

    def revert_received_tx_fee(target_block)
      target_block.update!(received_tx_fee: 0)
    end

    def decrease_records_count(local_tip_block)
      block_counter = TableRecordCount.find_by(table_name: "blocks")
      block_counter.decrement!(:count)
      ckb_transaction_counter = TableRecordCount.find_by(table_name: "ckb_transactions")
      normal_transactions = local_tip_block.ckb_transactions.normal
      ckb_transaction_counter.decrement!(:count, normal_transactions.count) if normal_transactions.present?
    end

    def recalculate_dao_contract_transactions_count(local_tip_block)
      dao_transactions_count = local_tip_block.ckb_transactions.where("tags @> array[?]::varchar[]", ["dao"]).count
      DaoContract.default_contract.decrement!(:ckb_transactions_count, dao_transactions_count) if dao_transactions_count > 0
    end

    def recalculate_udt_transactions_count(local_tip_block)
      udt_ids = local_tip_block.ckb_transactions.where("tags @> array[?]::varchar[]", ["udt"]).pluck(:contained_udt_ids).flatten
      udt_counts = udt_ids.each_with_object(Hash.new(0)) { |udt_id, counts| counts[udt_id] += 1 }
      udt_counts_value =
        udt_counts.map do |udt_id, count|
          udt = Udt.find(udt_id)
          { id: udt_id, ckb_transactions_count: udt.ckb_transactions_count - count, created_at: udt.created_at, updated_at: Time.current }
        end

      Udt.upsert_all(udt_counts_value) if udt_counts_value.present?
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

    def recalculate_udt_accounts(udt_type_hashes, local_tip_block)
      return if udt_type_hashes.blank?

      local_tip_block.contained_addresses.find_each do |address|
        udt_type_hashes.each do |type_hash|
          udt_account = address.udt_accounts.find_by(type_hash: type_hash)
          next if udt_account.blank?

          case udt_account.udt_type
          when "sudt"
            amount = address.cell_outputs.live.udt.where(type_hash: type_hash).sum(:udt_amount)
            udt_account.update!(amount: amount)
          when "m_nft_token"
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

    class LocalCache
      attr_accessor :cache

      def initialize
        @cache = {}
      end

      def fetch(key)
        return cache[key] if cache[key].present?

        if block_given? && yield.present?
          cache[key] = yield
        end
      end

      def write(key, value)
        cache[key] = value
      end

      def read(key)
        cache[key]
      end

      def push(key, value)
        if cache[key].present?
          cache[key] << value
        else
          cache[key] = Set.new.add(value)
        end
      end
    end
  end
end
