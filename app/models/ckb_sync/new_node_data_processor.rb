require "newrelic_rpm"
require "new_relic/agent/method_tracer"

module CkbSync
  class NewNodeDataProcessor
    include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
    include NewRelic::Agent::MethodTracer
    include Redis::Objects

    value :reorg_started_at, global: true
    attr_accessor :local_tip_block, :pending_raw_block, :ckb_txs, :target_block, :target_block_number,
                  :outputs, :inputs, :outputs_data, :udt_address_ids, :contained_address_ids,
                  :contained_udt_ids, :cell_datas, :enable_cota, :token_transfer_ckb_tx_ids, :addr_tx_changes, :redis_keys, :tx_previous_outputs

    # SSRI accounts are maintained by SsriContractWorker, so ssri cells are
    # intentionally excluded from the block processor's account updates.
    UDT_CELL_TYPES = %w(udt m_nft_token nrc_721_token spore_cell did_cell
                        omiga_inscription xudt xudt_compatible).freeze
    NFT_UDT_TYPES = %w(m_nft_token nrc_721_token spore_cell did_cell).freeze
    # Maps Udt/UdtAccount types to the cell_outputs.cell_type used for balance sums.
    UDT_AMOUNT_CELL_TYPES = {
      "sudt" => "udt",
      "xudt" => "xudt",
      "xudt_compatible" => "xudt_compatible",
      "omiga_inscription" => "omiga_inscription",
      "m_nft_token" => "m_nft_token",
      "spore_cell" => "spore_cell",
      "did_cell" => "did_cell",
    }.freeze
    UDT_ACCOUNT_SLOW_THRESHOLD_MS = 1_000

    def initialize(enable_cota = ENV["COTA_AGGREGATOR_URL"].present?)
      @enable_cota = enable_cota
      @local_cache = LocalCache.new
      @offset = ENV["BLOCK_OFFSET"].to_i
      @cell_datas = {} # data_hash => data
    end

    # returns the remaining block numbers to process
    def call
      @local_tip_block = Block.recent.first
      tip_block_number = @tip_block_number = CkbSync::Api.instance.get_tip_block_number
      @target_block_number = local_tip_block.present? ? local_tip_block.number + 1 : 0
      puts "Offset #{@offset}" if @offset > 0
      return if target_block_number > tip_block_number - @offset.to_i

      target_block = CkbSync::Api.instance.get_block_by_number(target_block_number)
      
      if forked?(target_block, local_tip_block)
        self.reorg_started_at = Time.now
        res = RevertBlockJob.perform_now(local_tip_block)
        reorg_started_at.delete
        res
      else
        Rails.logger.error "process_block: #{target_block_number}"
        res =
          ApplicationRecord.cache do
            process_block(target_block)
          end
        reorg_started_at.delete
        res
      end
    rescue StandardError => e
      Rails.logger.error e.message
      puts e.backtrace.join("\n")
      Rails.cache.delete_multi(@redis_keys)
      raise e
    end

    def process_block(node_block, refresh_balance: true)
      local_block = nil
      @redis_keys = []
      @tx_previous_outputs = {}

      ApplicationRecord.transaction do
        # build node data
        local_block = @local_block = benchmark(:build_block!, node_block)
        local_cache.write("BlockNumber", local_block.number)
        benchmark :build_uncle_blocks!, node_block, local_block.id
        inputs = @inputs = {}
        outputs = @outputs = {}
        outputs_data = @outputs_data = {}
        cell_deps = {}
        @ckb_txs = benchmark(:build_ckb_transactions!, node_block, local_block, inputs, outputs, outputs_data,
                             cell_deps).to_a
        benchmark :build_udts!, local_block, outputs, outputs_data

        tags = []
        @udt_address_ids = udt_address_ids = []
        @contained_udt_ids = contained_udt_ids = []
        @contained_address_ids = contained_address_ids = []
        @token_transfer_ckb_tx_ids = token_transfer_ckb_tx_ids = Set.new

        benchmark :process_ckb_txs, node_block, ckb_txs, contained_address_ids,
                  contained_udt_ids, tags, udt_address_ids
        @addr_tx_changes = Hash.new { |h, k| h[k] = Hash.new(0) }

        input_capacities, output_capacities = benchmark :build_cells_and_locks!, local_block, node_block, ckb_txs, inputs, outputs,
                                                        tags, udt_address_ids, contained_udt_ids, contained_address_ids, token_transfer_ckb_tx_ids, cell_deps

        # update explorer data
        benchmark :update_ckb_txs_rel_and_fee, ckb_txs, tags, input_capacities, output_capacities, udt_address_ids,
                  contained_udt_ids, contained_address_ids
        benchmark :update_block_info!, local_block
        benchmark :update_block_reward_info!, local_block
        benchmark :update_mining_info, local_block
        benchmark :update_table_records_count, local_block
        benchmark :update_or_create_udt_accounts!, local_block
        # maybe can be changed to asynchronous update
        benchmark :process_dao_events!, local_block
      end

      async_update_udt_infos(local_block)
      flush_inputs_outputs_caches(local_block)
      generate_statistics_data(local_block)
      detect_cota_infos(local_block)
      detect_token_transfer(token_transfer_ckb_tx_ids)
      detect_bitcoin_transactions(local_block)

      local_block.update_counter_for_ckb_node_version
      local_block
    end

    add_transaction_tracer :process_block, category: :task

    def check_invalid_address(address)
      if (address.balance < 0) || (address.balance_occupied < 0)
        wrong_balance = address.balance
        wrong_balance_occupied = address.balance_occupied
        Sentry.capture_message(
          "balance invalid",
          extra: {
            block: @tip_block_number,
            address: address.address_hash,
            wrong_balance:,
            wrong_balance_occupied:,
          },
        )
      end
    end

    private

    def generate_statistics_data(local_block)
      GenerateStatisticsDataWorker.perform_async(local_block.id)
    end

    def detect_cota_infos(local_block)
      FetchCotaWorker.perform_async(local_block.number) if enable_cota
    end

    def detect_token_transfer(token_transfer_ckb_tx_ids)
      token_transfer_ckb_tx_ids.each { TokenTransferDetectWorker.perform_async(_1) }
    end

    def detect_bitcoin_transactions(local_block)
      BitcoinTransactionDetectWorker.perform_async(local_block.number)
    end

    def async_update_udt_infos(local_block)
      UpdateUdtInfoWorker.perform_async(local_block.number)
    end

    def process_ckb_txs(
      node_block, ckb_txs, contained_address_ids, contained_udt_ids, tags, udt_address_ids
    )
      tx_index = 0
      ckb_txs.each do |cbk_tx|
        cbk_tx["tx_hash"][0] = "0"
        tags[tx_index] = Set.new
        udt_address_ids[tx_index] = Set.new
        contained_udt_ids[tx_index] = Set.new
        contained_address_ids[tx_index] = Set.new
        tx_index += 1
      end
      tx_hashes = node_block.transactions.map(&:hash)
      ckb_txs.sort_by! { |tx| tx_hashes.index(tx["tx_hash"]) }
    end

    attr_accessor :local_cache

    def flush_inputs_outputs_caches(local_block)
      FlushInputsOutputsCacheWorker.perform_async(local_block.id)
    end

    def increase_records_count(local_block)
      block_counter = TableRecordCount.find_or_initialize_by(table_name: "blocks")
      block_counter.increment!(:count)
      ckb_transaction_counter = TableRecordCount.find_or_initialize_by(table_name: "ckb_transactions")
      normal_transactions = local_block.ckb_transactions.normal.count
      if normal_transactions.present?
        ckb_transaction_counter.increment!(:count,
                                           normal_transactions.count)
      end
    end

    def process_dao_events!(local_tip_block = @local_tip_block)
      local_block = local_tip_block
      dao_contract = DaoContract.default_contract
      process_deposit_dao_events!(local_block, dao_contract)
      process_withdraw_dao_events!(local_block, dao_contract)
      process_interest_dao_events!(local_block, dao_contract)
      dao_contract.update(depositors_count: DaoEvent.depositor.distinct.count(:address_id))
    end

    # Process DAO withdraw
    # Warning：because DAO withdraw is also a cell, to the destination address of withdraw is the address of the withdraw cell output.
    # So it's possible that the deposit address is different with the withdraw address.
    def process_withdraw_dao_events!(local_block, dao_contract)
      dao_contract = DaoContract.default_contract
      withdraw_amount = 0
      withdraw_transaction_ids = Set.new
      addrs_withdraw_info = {}

      # When DAO Deposit Cell appears in cell inputs, the transaction is DAO withdrawal
      local_block.cell_inputs.nervos_dao_deposit.select(:id, :ckb_transaction_id,
                                                        :previous_cell_output_id, :index).find_in_batches do |dao_inputs|
        dao_events_attributes = []
        updated_deposit_dao_events_attributes = []
        dao_inputs.each do |dao_input|
          previous_cell_output =
            CellOutput.
              where(id: dao_input.previous_cell_output_id).
              select(:address_id, :ckb_transaction_id, :block_id, :dao, :cell_index, :capacity, :occupied_capacity).
              take!

          address = previous_cell_output.address
          address.dao_deposit ||= 0
          if addrs_withdraw_info.key?(address.id)
            addrs_withdraw_info[address.id][:dao_deposit] -= previous_cell_output.capacity
          else
            addrs_withdraw_info[address.id] = {
              dao_deposit: address.dao_deposit.to_i - previous_cell_output.capacity,
            }
          end
          if addrs_withdraw_info[address.id][:dao_deposit] == 0
            addrs_withdraw_info[address.id][:is_depositor] = false
            addrs_withdraw_info[address.id][:unclaimed_compensation] = address.cal_unclaimed_compensation
          end

          updated_deposit_dao_events_attributes << { block_id: previous_cell_output.block_id,
                                                     ckb_transaction_id: previous_cell_output.ckb_transaction_id,
                                                     cell_index: previous_cell_output.cell_index,
                                                     event_type: "deposit_to_dao",
                                                     consumed_transaction_id: dao_input.ckb_transaction_id,
                                                     consumed_block_timestamp: local_block.timestamp }
          dao_events_attributes << {
            ckb_transaction_id: dao_input.ckb_transaction_id,
            cell_index: dao_input.index,
            block_id: local_block.id,
            block_timestamp: local_block.timestamp,
            address_id: previous_cell_output.address_id,
            event_type: "withdraw_from_dao",
            value: previous_cell_output.capacity,
            status: "processed",
            contract_id: dao_contract.id,
          }
          withdraw_amount += previous_cell_output.capacity
          withdraw_transaction_ids << dao_input.ckb_transaction_id
        end
        if dao_events_attributes.present?
          dao_events_attributes.each_slice(500) do |batch|
            DaoEvent.upsert_all(batch, unique_by: %i[block_id ckb_transaction_id cell_index event_type]) 
          end
        end
        if updated_deposit_dao_events_attributes.present?
          updated_deposit_dao_events_attributes.each_slice(500) do |batch|
            DaoEvent.upsert_all(batch, unique_by: %i[block_id ckb_transaction_id cell_index event_type],
                                update_only: %i[consumed_transaction_id consumed_block_timestamp])
          end
        end
      end

      # update dao contract info
      dao_contract.update!(
        total_deposit: dao_contract.total_deposit - withdraw_amount
      )
      update_addresses_dao_info(addrs_withdraw_info)
    end

    # Process the interest of DAO deposit
    # After the previous withdraw step, destruct the nervos_dao_withdraw cell，returning free CKB，plus interest
    # eg. https://explorer.nervos.org/transaction/0xfbaaa415c34542148a15ead5c9f3e1e2cefd39ace57107244a1404ba0d56b8f1
    def process_interest_dao_events!(local_block, dao_contract)
      addrs_withdraw_info = {}
      claimed_compensation = 0
      local_block.cell_inputs.nervos_dao_withdrawing.select(:id, :ckb_transaction_id, :block_id, :index,
                                                            :previous_cell_output_id).find_in_batches do |dao_inputs|
        dao_events_attributes = []
        updated_withdraw_dao_events_attributes = []
        dao_inputs.each do |dao_input|
          previous_cell_output = CellOutput.
            where(id: dao_input.previous_cell_output_id).
            select(:address_id, :block_id, :ckb_transaction_id, :dao, :cell_index, :capacity, :occupied_capacity, :id).
            take!
          address = previous_cell_output.address

          interest = CkbUtils.dao_interest(previous_cell_output)
          if addrs_withdraw_info.key?(address.id)
            addrs_withdraw_info[address.id][:interest] += interest
          else
            addrs_withdraw_info[address.id] = {
              interest: address.interest.to_i + interest,
            }
          end

          unless address.is_depositor
            addrs_withdraw_info[address.id][:unclaimed_compensation] = 0
          end

          updated_withdraw_dao_events_attributes << { block_id: previous_cell_output.block_id,
                                                      ckb_transaction_id: previous_cell_output.ckb_transaction_id,
                                                      cell_index: previous_cell_output.cell_index,
                                                      event_type: "withdraw_from_dao",
                                                      consumed_transaction_id: dao_input.ckb_transaction_id,
                                                      consumed_block_timestamp: local_block.timestamp }

          # addrs_withdraw_info[address.id][:dao_deposit] = 0 if addrs_withdraw_info[address.id][:dao_deposit] < 0
          dao_events_attributes << {
            ckb_transaction_id: dao_input.ckb_transaction_id,
            cell_index: dao_input.index,
            block_id: local_block.id,
            block_timestamp: local_block.timestamp,
            address_id: previous_cell_output.address_id,
            event_type: "issue_interest",
            value: interest,
            status: "processed",
            contract_id: dao_contract.id,
          }
          claimed_compensation += interest
        end
        if dao_events_attributes.present?
          dao_events_attributes.each_slice(500) do |batch|
            DaoEvent.upsert_all(batch, unique_by: %i[block_id ckb_transaction_id cell_index event_type])
          end
        end
        
        if updated_withdraw_dao_events_attributes.present?
          updated_withdraw_dao_events_attributes.each_slice(500) do |batch|
            DaoEvent.upsert_all(batch, unique_by: %i[block_id ckb_transaction_id cell_index event_type],
                                                                      update_only: %i[consumed_transaction_id consumed_block_timestamp])
          end
        end
      end
      # update dao contract info
      dao_contract.update!(
        claimed_compensation: dao_contract.claimed_compensation + claimed_compensation,
      )
      update_addresses_dao_info(addrs_withdraw_info)
    end

    def process_deposit_dao_events!(local_block, dao_contract)
      deposit_amount = 0
      deposit_transaction_ids = Set.new
      addresses_deposit_info = {}
      # build deposit dao events
      local_block.cell_outputs.nervos_dao_deposit.select(:id, :address_id, :capacity,
                                                         :ckb_transaction_id, :cell_index).find_in_batches do |dao_outputs|
        dao_events_attributes = []
        dao_outputs.each do |dao_output|
          address = dao_output.address
          address.dao_deposit ||= 0
          if addresses_deposit_info.key?(address.id)
            addresses_deposit_info[address.id][:dao_deposit] += dao_output.capacity
          else
            addresses_deposit_info[address.id] =
              {
                dao_deposit: address.dao_deposit.to_i + dao_output.capacity,

              }
          end
          addresses_deposit_info[address.id][:is_depositor] = true
          deposit_amount += dao_output.capacity
          deposit_transaction_ids << dao_output.ckb_transaction_id
          dao_events_attributes << {
            ckb_transaction_id: dao_output.ckb_transaction_id,
            cell_index: dao_output.cell_index,
            cell_output_id: dao_output.id,
            block_id: local_block.id,
            address_id: address.id,
            event_type: "deposit_to_dao",
            value: dao_output.capacity,
            status: "processed",
            contract_id: dao_contract.id,
            block_timestamp: local_block.timestamp,
          }
        end
        if dao_events_attributes.present?
          dao_events_attributes.each_slice(500) do |batch|
            DaoEvent.upsert_all(batch, unique_by: %i[block_id ckb_transaction_id cell_index event_type])
          end
        end
        Rails.cache.delete("unmade_dao_interests")
      end
      # update dao contract info
      dao_contract.update!(
        total_deposit: dao_contract.total_deposit + deposit_amount
      )

      update_addresses_dao_info(addresses_deposit_info)
    end

    def update_addresses_dao_info(addrs_deposit_info)
      addresses_deposit_attributes = []
      addrs_deposit_info.each do |address_id, address_info|
        addresses_deposit_attributes << {
          id: address_id,
          dao_deposit: address_info[:dao_deposit],
          interest: address_info[:interest],
          is_depositor: address_info[:is_depositor],
          unclaimed_compensation: address_info[:unclaimed_compensation]
        }
      end
      if addresses_deposit_attributes.present?
        addresses_deposit_attributes.each_slice(500) do |batch|
          Address.upsert_all(
            batch,
            record_timestamps: true,
            on_duplicate: Arel.sql(
              "dao_deposit = COALESCE(EXCLUDED.dao_deposit, addresses.dao_deposit), " \
              "interest = COALESCE(EXCLUDED.interest, addresses.interest), " \
              "is_depositor = COALESCE(EXCLUDED.is_depositor, addresses.is_depositor)",
            ),
          )
        end
      end
    end

    def update_or_create_udt_accounts!(local_block)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      timings = {}

      token_outputs, consumed_outputs = measure_udt_step(timings, :cell_outputs) do
        udt_cell_outputs_for(local_block)
      end
      return if token_outputs.empty? && consumed_outputs.empty?

      type_script_args = measure_udt_step(timings, :type_script_args) do
        type_script_args_for(token_outputs)
      end
      all_outputs = token_outputs + consumed_outputs
      udts_by_key = measure_udt_step(timings, :load_udts) do
        load_udts_for(all_outputs)
      end
      accounts_by_key = measure_udt_step(timings, :load_accounts) do
        load_udt_accounts_for(all_outputs)
      end
      amounts = measure_udt_step(timings, :load_amounts) do
        load_udt_account_amounts(all_outputs)
      end

      new_accounts = {}
      account_updates = {}
      measure_udt_step(timings, :build_outputs) do
        build_output_udt_accounts(token_outputs, type_script_args, udts_by_key, accounts_by_key, amounts,
                                  new_accounts, account_updates)
      end
      measure_udt_step(timings, :build_consumed) do
        build_consumed_udt_accounts(consumed_outputs, udts_by_key, accounts_by_key, amounts,
                                    new_accounts, account_updates)
      end
      destroy_ids = measure_udt_step(timings, :burned_nfts) do
        burned_nft_account_ids(consumed_outputs, udts_by_key, accounts_by_key,
                               new_accounts, account_updates)
      end

      measure_udt_step(timings, :delete) do
        UdtAccount.where(id: destroy_ids).delete_all if destroy_ids.any?
      end
      measure_udt_step(timings, :persist) do
        persist_udt_account_changes(new_accounts, account_updates)
      end

      total_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
      log_udt_account_timings(local_block, token_outputs, consumed_outputs, all_outputs, accounts_by_key,
                              amounts, new_accounts, account_updates, destroy_ids, timings, total_ms)
    end

    def measure_udt_step(timings, name)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      timings[name] = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)
      result
    end

    # Logs slow blocks by default; set UDT_ACCOUNT_TIMING_LOG=1 to log every block.
    def log_udt_account_timings(local_block, token_outputs, consumed_outputs, all_outputs, accounts_by_key,
                                amounts, new_accounts, account_updates, destroy_ids, timings, total_ms)
      slow = total_ms >= UDT_ACCOUNT_SLOW_THRESHOLD_MS
      return unless slow || ENV["UDT_ACCOUNT_TIMING_LOG"] == "1"

      type_hashes = all_outputs.filter_map(&:type_hash)
      timing_details = timings.map { |name, ms| "#{name}=#{ms}ms" }.join(" ")
      message = "[udt-account] block=#{local_block.number} outputs=#{token_outputs.size} " \
                "consumed=#{consumed_outputs.size} type_hashes=#{type_hashes.uniq.size} " \
                "accounts=#{accounts_by_key.size} amount_keys=#{amounts.size} " \
                "new=#{new_accounts.size} updates=#{account_updates.size} destroys=#{destroy_ids.size} " \
                "#{timing_details} total=#{total_ms.round(1)}ms"
      if slow
        top_types = top_udt_type_hashes(type_hashes)
        message += " top_types=#{top_types}" if top_types.present?
      end
      Rails.logger.info(message)
    end

    def top_udt_type_hashes(type_hashes)
      type_hashes.tally.sort_by { |type_hash, count| [-count, type_hash] }.first(5).
        map { |type_hash, count| "#{type_hash}:#{count}" }.join(",")
    end

    def udt_cell_outputs_for(local_block)
      block_outputs = local_block.cell_outputs.
        select(:id, :address_id, :type_hash, :cell_type, :type_script_id).to_a
      token_outputs = block_outputs.select { |output| udt_cell_output?(output) }
      consumed_outputs = (@tx_previous_outputs || {}).values.flatten.compact.
        select { |output| udt_cell_output?(output) }
      [token_outputs, consumed_outputs]
    end

    def build_output_udt_accounts(token_outputs, type_script_args, udts_by_key, accounts_by_key, amounts,
                                  new_accounts, account_updates)
      token_outputs.each do |output|
        udt_type = udt_type(output.cell_type)
        udt = udts_by_key[[output.type_hash, udt_type]]
        unless udt
          log_missing_udt(output, udt_type)
          next
        end

        key = [output.address_id.to_i, output.type_hash]
        amount = udt_amount_for(amounts, output, udt_type)
        if (account = accounts_by_key[key])
          account_updates[account.id] = { id: account.id, amount:, created_at: udt.created_at }
        else
          new_accounts[key] = new_udt_account_attributes(output, udt, amount, type_script_args)
        end
      end
    end

    def build_consumed_udt_accounts(consumed_outputs, udts_by_key, accounts_by_key, amounts,
                                    new_accounts, account_updates)
      consumed_outputs.each do |output|
        udt_type = udt_type(output.cell_type)
        next if NFT_UDT_TYPES.include?(udt_type)

        key = [output.address_id.to_i, output.type_hash]
        account = accounts_by_key[key]
        next if account.nil?
        next if new_accounts.key?(key) || account_updates.key?(account.id)

        udt = udts_by_key[[output.type_hash, udt_type]]
        unless udt
          log_missing_udt(output, udt_type)
          next
        end

        amount = udt_amount_for(amounts, output, udt_type)
        account_updates[account.id] = { id: account.id, amount:, created_at: udt.created_at }
      end
    end

    def burned_nft_account_ids(consumed_outputs, udts_by_key, accounts_by_key, new_accounts, account_updates)
      nft_keys = consumed_outputs.filter_map { |output| nft_consumed_key(output) }.uniq
      return [] if nft_keys.empty?

      live_keys = live_udt_keys(nft_keys)
      nft_keys.filter_map do |key|
        next unless udts_by_key[[key[1], key[2]]]
        next if live_keys.include?(key)

        account = accounts_by_key[[key[0], key[1]]]
        if account
          # An output pass may have staged an update for an intermediate cell
          # that was consumed later in this block. Final liveness wins.
          account_updates.delete(account.id)
          account.id
        else
          new_accounts.delete([key[0], key[1]])
          nil
        end
      end
    end

    def nft_consumed_key(output)
      udt_type = udt_type(output.cell_type)
      [output.address_id.to_i, output.type_hash, udt_type] if NFT_UDT_TYPES.include?(udt_type)
    end

    def new_udt_account_attributes(output, udt, amount, type_script_args)
      {
        address_id: output.address_id,
        udt_type: udt.udt_type,
        full_name: udt.full_name,
        symbol: udt.symbol,
        decimal: udt.decimal,
        published: udt.published,
        code_hash: udt.code_hash,
        type_hash: udt.type_hash,
        amount:,
        udt_id: udt.id,
        nft_token_id: nft_token_id_for(output, udt_type(output.cell_type), type_script_args),
      }
    end

    def persist_udt_account_changes(new_accounts, account_updates)
      new_accounts.values.each_slice(500) do |batch|
        UdtAccount.insert_all!(batch, record_timestamps: true)
      end
      account_updates.values.each_slice(500) do |batch|
        UdtAccount.upsert_all(batch, record_timestamps: true)
      end
    end

    def udt_cell_output?(output)
      output.type_hash.present? && output.cell_type.in?(UDT_CELL_TYPES)
    end

    def udt_type(cell_type)
      cell_type == "udt" ? "sudt" : cell_type
    end

    # Loads all type script args needed for NFT token ids in one query.
    def type_script_args_for(outputs)
      type_script_ids = outputs.filter_map(&:type_script_id).uniq
      return {} if type_script_ids.empty?

      TypeScript.where(id: type_script_ids).pluck(:id, :args).to_h
    end

    # Loads all Udt records touched by this block, keyed by [type_hash, udt_type].
    def load_udts_for(outputs)
      keys = outputs.map { |output| [output.type_hash, udt_type(output.cell_type)] }.uniq
      return {} if keys.empty?

      Udt.where(
        type_hash: keys.map(&:first).uniq,
        udt_type: keys.map(&:last).uniq,
      ).select(
        :id, :udt_type, :full_name, :symbol, :decimal, :published, :code_hash, :type_hash, :created_at
      ).each_with_object({}) do |udt, result|
        result[[udt.type_hash, udt.udt_type]] ||= udt
      end
    end

    # Loads all existing accounts touched by this block, keyed by [address_id, type_hash].
    # udt_accounts has a unique index on (type_hash, address_id), so one row per key.
    def load_udt_accounts_for(outputs)
      keys = outputs.map { |output| [output.address_id.to_i, output.type_hash] }.uniq
      return {} if keys.empty?

      condition, *values = composite_in_condition(%w[address_id type_hash], keys)
      UdtAccount.where(condition, *values).select(:id, :address_id, :type_hash).each_with_object({}) do |account, result|
        result[[account.address_id.to_i, account.type_hash]] ||= account
      end
    end

    # Computes all live balances for this block in one grouped query instead of
    # one SUM per UDT cell output.
    def load_udt_account_amounts(outputs)
      query_keys = outputs.filter_map do |output|
        next if output.type_hash.blank?

        cell_type = UDT_AMOUNT_CELL_TYPES[udt_type(output.cell_type)]
        [output.address_id.to_i, output.type_hash, cell_type] if cell_type
      end.uniq
      return {} if query_keys.empty?

      sql_keys = query_keys.map do |address_id, type_hash, cell_type|
        [address_id, type_hash, CellOutput.cell_types[cell_type] || cell_type]
      end
      condition, *values = composite_in_condition(%w[address_id type_hash cell_type], sql_keys)
      rows = CellOutput.live.
        where(condition, *values).
        group(:address_id, :type_hash, :cell_type).
        sum(:udt_amount)

      rows.each_with_object({}) do |((address_id, type_hash, cell_type), amount), amounts|
        amounts[[normalize_address_id(address_id), type_hash, normalize_cell_type(cell_type)]] = amount
      end
    end

    # Returns the [address_id, type_hash, cell_type] keys that still have a live output.
    def live_udt_keys(keys)
      return Set.new if keys.empty?

      sql_keys = keys.map do |address_id, type_hash, cell_type|
        [address_id, type_hash, CellOutput.cell_types[cell_type] || cell_type]
      end
      condition, *values = composite_in_condition(%w[address_id type_hash cell_type], sql_keys)
      rows = CellOutput.live.
        where(condition, *values).
        group(:address_id, :type_hash, :cell_type).
        count

      rows.each_with_object(Set.new) do |((address_id, type_hash, cell_type), _count), result|
        result << [normalize_address_id(address_id), type_hash, normalize_cell_type(cell_type)]
      end
    end

    # Builds a parameterized row-value IN clause so multi-column lookups use
    # exactly the keys touched by the block instead of the cross-product of
    # independent IN lists.
    def composite_in_condition(columns, keys)
      placeholders = keys.map { "(#{Array.new(columns.size, '?').join(', ')})" }.join(", ")
      ["(#{columns.join(', ')}) IN (#{placeholders})", *keys.flatten]
    end

    def udt_amount_for(amounts, output, udt_type)
      cell_type = UDT_AMOUNT_CELL_TYPES[udt_type]
      return 0 if cell_type.nil?

      amounts.fetch([output.address_id.to_i, output.type_hash, cell_type], 0)
    end

    def nft_token_id_for(output, udt_type, type_script_args)
      return unless NFT_UDT_TYPES.include?(udt_type)

      args = type_script_args[output.type_script_id]
      return if args.nil?

      case udt_type
      when "nrc_721_token"
        CkbUtils.parse_nrc_721_args(args).token_id
      when "spore_cell", "did_cell"
        args.hex
      end
    end

    def normalize_address_id(address_id)
      address_id.to_i
    end

    def normalize_cell_type(cell_type)
      return cell_type unless cell_type.is_a?(Integer)

      CellOutput.cell_types.key(cell_type) || cell_type
    end

    def log_missing_udt(output, udt_type)
      Rails.logger.error(
        "Missing Udt, skip udt account update: cell_output_id=#{output.id}, " \
        "cell_type=#{output.cell_type}, type_hash=#{output.type_hash}, udt_type=#{udt_type}",
      )
    end

    def update_table_records_count(local_block)
      Block.connection.execute "UPDATE blocks SET cycles=(SELECT SUM(cycles) FROM ckb_transactions WHERE block_id=#{local_block.id}) WHERE id=#{local_block.id}"
      block_counter = TableRecordCount.find_or_initialize_by(table_name: "blocks")
      block_counter.increment!(:count)
      ckb_transaction_counter = TableRecordCount.find_or_initialize_by(table_name: "ckb_transactions")
      normal_transactions = local_block.ckb_transactions.normal
      if normal_transactions.present?
        ckb_transaction_counter.increment!(:count,
                                           normal_transactions.count)
      end
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

    def update_block_info!(local_block)
      local_block.update!(
        total_transaction_fee: local_block.ckb_transactions.sum(:transaction_fee),
        ckb_transactions_count: local_block.ckb_transactions.count,
        live_cell_changes: local_block.ckb_transactions.sum(&:live_cell_changes),
        address_ids: @contained_address_ids.map(&:to_a).flatten.uniq
      )
    end

    def build_udts!(local_block, outputs, outputs_data)
      udts_attributes = Set.new
      omiga_inscription_udt_attributes = Set.new

      outputs.each do |tx_index, items|
        items.each_with_index do |output, index|
          cell_type = cell_type(output.type, outputs_data[tx_index][index])
          next unless cell_type.in?(%w(udt m_nft_token nrc_721_token spore_cell did_cell
                                       omiga_inscription_info omiga_inscription xudt xudt_compatible))

          type_hash, parsed_udt_type =
            if cell_type == "omiga_inscription_info"
              info = CkbUtils.parse_omiga_inscription_info(outputs_data[tx_index][index])
              info_type_hash = output.type.compute_hash
              pre_closed_info = OmigaInscriptionInfo.includes(:udt).find_by(
                type_hash: info_type_hash, mint_status: :closed,
              )
              attrs = info.merge(output.type.to_h, type_hash: info_type_hash)
              if pre_closed_info
                attrs[:pre_udt_hash] = pre_closed_info.udt_hash
                attrs[:is_repeated_symbol] = pre_closed_info.is_repeated_symbol
              else
                attrs[:is_repeated_symbol] = OmigaInscriptionInfo.where(symbol: CkbUtils.sanitize_string(info[:symbol])).exists?
              end
              OmigaInscriptionInfo.upsert(attrs, unique_by: :udt_hash)
              [info[:udt_hash], "omiga_inscription"]
            else
              [output.type.compute_hash, udt_type(cell_type)]
            end

          if cell_type == "omiga_inscription"
            omiga_inscription_udt_attributes << { type_hash:,
                                                  code_hash: output.type.code_hash, hash_type: output.type.hash_type, args: output.type.args }
          end

          unless Udt.where(type_hash:).exists?
            nft_token_attr = { full_name: "", icon_file: "",
                               published: false, symbol: "", decimal: nil, nrc_factory_cell_id: nil }
            issuer_address = CkbUtils.generate_address(output.lock, CKB::Address::Version::CKB2021)
            case cell_type
            when "m_nft_token"
              m_nft_class_type = TypeScript.where(code_hash: CkbSync::Api.instance.token_class_script_code_hash,
                                                  args: output.type.args[0..49]).first
              if m_nft_class_type.present?
                m_nft_class_cell = m_nft_class_type.cell_outputs.where(status: %i[pending live]).order(id: :desc).first
                m_nft_class_cell = m_nft_class_type.cell_outputs.dead.order(id: :desc).first unless m_nft_class_cell
                parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
                TokenCollection.find_or_create_by(
                  standard: "m_nft",
                  name: CkbUtils.sanitize_string(parsed_class_data.name),
                  cell_id: m_nft_class_cell.id,
                  block_timestamp: m_nft_class_cell.block_timestamp,
                  icon_url: CkbUtils.sanitize_string(parsed_class_data.renderer),
                  creator_id: m_nft_class_cell.address_id,
                )

                nft_token_attr[:full_name] = CkbUtils.sanitize_string(parsed_class_data.name)
                nft_token_attr[:icon_file] = CkbUtils.sanitize_string(parsed_class_data.renderer)
                nft_token_attr[:published] = true
              end
            when "spore_cell", "did_cell"
              nft_token_attr[:published] = true
              parsed_spore_cell = CkbUtils.parse_spore_cell_data(outputs_data[tx_index][index])
              if parsed_spore_cell[:cluster_id].present?
                binary_hashes = CkbUtils.hexes_to_bins_sql(CkbSync::Api.instance.spore_cluster_code_hashes)
                spore_cluster_type_ids = TypeScript.where("code_hash IN (#{binary_hashes})").where(hash_type: "data1", args: parsed_spore_cell[:cluster_id]).pluck(:id)
                if spore_cluster_type_ids.present?
                  spore_cluster_cell = CellOutput.where(type_script_id: spore_cluster_type_ids, status: %i[pending live]).last
                  parsed_cluster_data = CkbUtils.parse_spore_cluster_data(spore_cluster_cell.data)
                  nft_token_attr[:full_name] = CkbUtils.sanitize_string(parsed_cluster_data[:name].to_s)
                end
              end
            when "nrc_721_token"
              factory_cell = CkbUtils.parse_nrc_721_args(output.type.args)
              nrc_721_factory_cell = NrcFactoryCell.create_or_find_by(code_hash: factory_cell.code_hash,
                                                                      hash_type: factory_cell.hash_type,
                                                                      args: factory_cell.args)
              nft_token_attr[:full_name] = nrc_721_factory_cell.name
              nft_token_attr[:symbol] =
                nrc_721_factory_cell.symbol.to_s[0, 16]
              nft_token_attr[:icon_file] =
                "#{nrc_721_factory_cell.base_token_uri}/#{factory_cell.token_id}"
              # refactor: remove this attribute then add udt_id to NrcFactoryCell
              nft_token_attr[:nrc_factory_cell_id] = nrc_721_factory_cell.id
              nft_token_attr[:published] = true
            when "omiga_inscription_info"
              info = CkbUtils.parse_omiga_inscription_info(outputs_data[tx_index][index])
              nft_token_attr[:full_name] = CkbUtils.sanitize_string(info[:name])
              nft_token_attr[:symbol] = CkbUtils.sanitize_string(info[:symbol])
              nft_token_attr[:decimal] = info[:decimal]
              nft_token_attr[:published] = true
            when "xudt", "xudt_compatible"
              if output.type.args.length == 66
                issuer_address = Address.find_by(lock_hash: output.type.args[0..65])&.address_hash
              end
              items.each_with_index do |output, index|
                if output.type&.code_hash == CkbSync::Api.instance.unique_cell_code_hash
                  info = CkbUtils.parse_unique_cell(outputs_data[tx_index][index])
                  nft_token_attr[:full_name] = CkbUtils.sanitize_string(info[:name])
                  nft_token_attr[:symbol] = CkbUtils.sanitize_string(info[:symbol])
                  nft_token_attr[:decimal] = info[:decimal]
                  nft_token_attr[:published] = true
                end
              end
            end
            udts_attributes << {
              type_hash:, udt_type: parsed_udt_type, block_timestamp: local_block.timestamp, args: output.type.args,
              code_hash: output.type.code_hash, hash_type: output.type.hash_type, issuer_address:
            }.merge(nft_token_attr)
          end
        end
      end
      if udts_attributes.present?
        unique_udt_attributes = udts_attributes.uniq { |ua| ua[:type_hash] }
        returning_attrs = Udt.insert_all!(unique_udt_attributes, record_timestamps: true, returning: %w[id udt_type type_hash])
        omiga_inscription_info_attrs = returning_attrs.rows.filter do |r|
                                         r[1] == 4
                                       end.map do |k|
          { udt_id: k[0],
            udt_hash: k[2] }
        end
        if omiga_inscription_info_attrs.present?
          OmigaInscriptionInfo.upsert_all(omiga_inscription_info_attrs,
                                          unique_by: :udt_hash)
        end
      end

      if omiga_inscription_udt_attributes.present?
        Udt.upsert_all(omiga_inscription_udt_attributes, unique_by: :type_hash)
      end
    end

    def update_ckb_txs_rel_and_fee(
      ckb_txs, tags, input_capacities, output_capacities, udt_address_ids, contained_udt_ids, contained_addr_ids
    )
      ckb_transactions_attributes = []
      tx_index = 0
      full_tx_address_ids = []
      full_tx_udt_ids = []
      full_udt_address_ids = []
      ckb_txs.each do |tx|
        tx_id = tx["id"]
        full_tx_address_ids +=
          contained_addr_ids[tx_index].to_a.map do |address_id|
            { address_id:, ckb_transaction_id: tx_id, income: addr_tx_changes[tx_index][address_id], block_number: tx["block_number"], tx_index: }
          end
        full_tx_udt_ids += contained_udt_ids[tx_index].to_a.compact.map do |u|
          { udt_id: u, ckb_transaction_id: tx_id }
        end
        full_udt_address_ids += udt_address_ids[tx_index].to_a.map do |a|
          { address_id: a, ckb_transaction_id: tx_id }
        end

        attr = {
          id: tx_id,
          tags: tags[tx_index].to_a,
          tx_status: "committed",
          capacity_involved: input_capacities[tx_index],
          transaction_fee:
            if tx_index == 0
              0
            else
              CkbUtils.ckb_transaction_fee(tx, input_capacities[tx_index],
                                           output_capacities[tx_index], @tx_previous_outputs[tx_id] || [])
            end,
          created_at: tx["created_at"],
          updated_at: Time.current,
        }

        # binding.pry if attr[:transaction_fee] < 0
        ckb_transactions_attributes << attr
        tx_index += 1
      end

      if ckb_transactions_attributes.present?
        ckb_transactions_attributes.each_slice(500) do |batch|
          CkbTransaction.upsert_all(batch,
            unique_by: %i[id tx_status])
        end
      end
      if full_tx_address_ids.present?
        AccountBook.import full_tx_address_ids, validate: false, batch_size: 500
      end
      if full_tx_udt_ids.present?
        full_tx_udt_ids.each_slice(500) do |batch|
          UdtTransaction.upsert_all batch,
                                    unique_by: %i[udt_id
                                                  ckb_transaction_id]
        end
      end
      if full_udt_address_ids.present?
        full_udt_address_ids.each_slice(500) do |batch|
          AddressUdtTransaction.upsert_all batch,
                                          unique_by: %i[address_id
                                                        ckb_transaction_id]
        end
      end
    end

    def build_cells_and_locks!(
      local_block, node_block, ckb_txs, inputs, outputs, tags, udt_address_ids,
       contained_udt_ids, contained_addr_ids, token_transfer_ckb_tx_ids, cell_deps
    )
      # Resolve locks, type scripts, and addresses once per block instead of once per output.
      @lock_script_ids = {}
      @type_script_ids = {}
      @address_ids = {}
      @redis_keys ||= []

      cell_outputs_attributes = []
      cell_inputs_attributes = []
      prev_cell_outputs_attributes = []
      input_capacities = []
      output_capacities = []
      lock_scripts_attributes, type_scripts_attributes = ApplicationRecord.benchmark("build_scripts") do
        build_scripts(outputs)
      end

      if lock_scripts_attributes.any?
        ApplicationRecord.benchmark("lock_scripts_upsert") do
          lock_scripts_attributes.each_slice(500) do |batch|
            result = LockScript.upsert_all(
              batch, unique_by: :script_hash, returning: %i[id script_hash], record_timestamps: true,
            )
            record_script_ids(result, @lock_script_ids)
          end
        end
      end
      if type_scripts_attributes.any?
        ApplicationRecord.benchmark("type_scripts_upsert") do
          type_scripts_attributes.each_slice(500) do |batch|
            result = TypeScript.upsert_all(
              batch, unique_by: :script_hash, returning: %i[id script_hash], record_timestamps: true,
            )
            record_script_ids(result, @type_script_ids)
          end
        end
      end

      ApplicationRecord.benchmark("build_addresses") do
        build_addresses!(outputs, local_block)
      end

      ApplicationRecord.benchmark("build_cell_outputs") do
        build_cell_outputs!(node_block, outputs, ckb_txs, local_block, cell_outputs_attributes, output_capacities, tags,
                            udt_address_ids, contained_udt_ids, contained_addr_ids, token_transfer_ckb_tx_ids)
      end
      if cell_outputs_attributes.present?
        tx_hashes = cell_outputs_attributes.pluck(:tx_hash)
        binary_hashes = CkbUtils.hexes_to_bins_sql(tx_hashes)
        ApplicationRecord.benchmark("cell_outputs_pending_update") do
          CellOutput.pending.where("tx_hash IN (#{binary_hashes})").update_all(status: :live)
        end
        id_hashes = []
        cell_outputs_attributes.each_slice(500) do |batch|
          result = ApplicationRecord.benchmark("cell_outputs_import") do
            CellOutput.import(batch, validate: false, returning: %i[id data_hash])
          end.results
          id_hashes.concat result.map{|item| {"id" => item[0], "data_hash" => item[1]} }
        end
        cell_data_attrs = []

        id_hashes.each do |row|
          hash = row["data_hash"]
          if hash.present?
            hash[0] = "0"
            hash = CKB::Utils.hex_to_bin(hash)
            cell_data_attrs << { cell_output_id: row["id"],
                                 data: @cell_datas[hash] }
          end
        end

        if cell_data_attrs.present?
          ApplicationRecord.benchmark("cell_datum_import") do
            CellDatum.import cell_data_attrs, validate: false, batch_size: 500
          end
        end
      end

      hash2index = {}
      hash2id = {}
      ckb_txs.each do |t|
        hash2id["0#{t['tx_hash'][1..]}"] = t["id"]
        hash2index["0#{t['tx_hash'][1..]}"] = t["tx_index"]
      end

      cell_deps_attrs = []
      cell_outputs_by_pointer = {}
      cell_deps.each do |tx_hash, cell_deps|
        txid = hash2id[tx_hash]
        tx_index = hash2index[tx_hash]

        cell_deps.each do |cell_dep|
          out_point = cell_dep.out_point
          cell_index = out_point.index.is_a?(String) ? out_point.index.hex : out_point.index
          pointer = [out_point.tx_hash, cell_index]
          unless cell_outputs_by_pointer.key?(pointer)
            cell_outputs_by_pointer[pointer] = CellOutput.find_by_pointer(out_point.tx_hash, cell_index)
          end

          cell_output = cell_outputs_by_pointer[pointer]
          unless cell_output
            raise "CellOutput not found for cell dependency #{out_point.tx_hash}##{out_point.index}"
          end

          cell_deps_attrs <<
            {
              ckb_transaction_id: txid,
              dep_type: cell_dep.dep_type,
              contract_cell_id: cell_output.id,
              block_number: local_block.number,
              tx_index:,
            }
        end
      end
      if cell_deps_attrs.present?
        ApplicationRecord.benchmark("cell_deps_import") do
          CellDependency.import cell_deps_attrs, validate: false, batch_size: 500
        end
      end

      prev_outputs = nil
      ApplicationRecord.benchmark("build_cell_inputs") do
        build_cell_inputs(inputs, ckb_txs, local_block.id, cell_inputs_attributes, prev_cell_outputs_attributes,
                          input_capacities, tags, udt_address_ids, contained_udt_ids, contained_addr_ids,
                          prev_outputs, token_transfer_ckb_tx_ids)
      end

      ApplicationRecord.benchmark("cell_inputs_import") do
        CellInput.import cell_inputs_attributes, validate: false, batch_size: 500
      end
      if prev_cell_outputs_attributes.present?
        prev_cell_outputs_attributes.each_slice(500) do |batch|
          updates = batch.map do |attr|
            [attr[:id], attr.slice(:status, :consumed_by_id, :consumed_block_timestamp)]
          end.to_h

          case_clauses = { status: [], consumed_by_id: [], consumed_block_timestamp: [] }
          ids = []
    
          updates.each do |id, attrs|
            ids << id
            attrs.each do |column, value|
              case_clauses[column] << "WHEN #{id} THEN '#{ActiveRecord::Base.connection.quote(value)}'"
            end
          end
          
          set_clauses = case_clauses.map do |column, clauses|
            if clauses.any?
              "  #{column} = CASE id\n    #{clauses.join("\n    ")}\n    ELSE #{column}\n  END"
            else
              nil
            end
          end.compact.join(",\n")
          
          id_list = ids.join(', ')
          
          sql = <<-SQL
            UPDATE cell_outputs
            SET
              #{set_clauses}
            WHERE id IN (#{id_list})
          SQL
          
          # puts sql
    
          ApplicationRecord.benchmark("prev_outputs_update") do
            ActiveRecord::Base.connection.execute(sql)
          end
        end
      end

      [input_capacities, output_capacities]
    end

    def build_addresses!(outputs, local_block)
      @address_ids ||= {}
      @lock_script_ids ||= {}
      @redis_keys ||= []

      locks_by_hash = {}
      outputs.each_value do |items|
        items.each do |item|
          lock_hash = item.lock.compute_hash
          locks_by_hash[lock_hash] ||= item.lock
        end
      end
      return if locks_by_hash.empty?

      cache_keys = locks_by_hash.keys.map { |lock_hash| "address_lock_hash_#{lock_hash}" }
      Rails.cache.read_multi(*cache_keys).each do |key, address_id|
        next if address_id.nil?

        @address_ids[key.delete_prefix("address_lock_hash_")] = address_id
      end

      missing_hashes = locks_by_hash.keys.reject { |lock_hash| @address_ids.key?(lock_hash) }
      return if missing_hashes.empty?

      cache_entries = {}
      existing_hashes = []
      missing_hashes.each_slice(500) do |batch|
        Address.where(lock_hash: batch).pluck(:lock_hash, :id).each do |lock_hash, address_id|
          lock_hash = normalize_bytea_value(lock_hash)
          @address_ids[lock_hash] = address_id
          cache_entries["address_lock_hash_#{lock_hash}"] = address_id
          existing_hashes << lock_hash
        end
      end

      # Keep the existing repair path for addresses that are already in the DB.
      existing_hashes.each do |lock_hash|
        address = Address.find_or_create_address(
          locks_by_hash[lock_hash], local_block.timestamp,
          @lock_script_ids[lock_hash] || lock_script_id_for(lock_hash),
        )
        @address_ids[lock_hash] = address.id
        cache_entries["address_lock_hash_#{lock_hash}"] = address.id
      end

      new_hashes = missing_hashes.reject { |lock_hash| @address_ids.key?(lock_hash) }
      if new_hashes.any?
        new_address_attributes = new_hashes.map do |lock_hash|
          {
            lock_hash:,
            address_hash: CkbUtils.generate_address(
              locks_by_hash[lock_hash], CKB::Address::Version::CKB2021,
            ),
            block_timestamp: local_block.timestamp,
            lock_script_id: @lock_script_ids[lock_hash] || lock_script_id_for(lock_hash),
          }
        end
        new_address_attributes.each_slice(500) do |batch|
          Address.insert_all(
            batch, returning: %i[id lock_hash], record_timestamps: true,
          ).rows.each do |id, lock_hash|
            lock_hash = normalize_bytea_value(lock_hash)
            @address_ids[lock_hash] = id
            cache_entries["address_lock_hash_#{lock_hash}"] = id
          end
        end
      end

      return if cache_entries.empty?

      Rails.cache.write_multi(cache_entries)
      @redis_keys.concat(cache_entries.keys)
    end

    def build_scripts(outputs)
      @lock_script_ids ||= {}
      @type_script_ids ||= {}

      locks_by_hash = {}
      types_by_hash = {}
      outputs.each_value do |items|
        items.each do |output|
          lock_hash = output.lock.compute_hash
          locks_by_hash[lock_hash] ||= output.lock

          next if output.type.blank?

          type_hash = output.type.compute_hash
          types_by_hash[type_hash] ||= output.type
        end
      end

      lock_scripts_attributes = fetch_scripts(
        locks_by_hash, "lock_script_hash_", LockScript, @lock_script_ids,
      )
      type_scripts_attributes = fetch_scripts(
        types_by_hash, "type_script_hash_", TypeScript, @type_script_ids,
      )

      [lock_scripts_attributes, type_scripts_attributes]
    end

    def fetch_scripts(scripts_by_hash, key_prefix, script_class, script_ids)
      return [] if scripts_by_hash.empty?

      @redis_keys ||= []
      cache_keys = scripts_by_hash.keys.map { |script_hash| "#{key_prefix}#{script_hash}" }
      Rails.cache.read_multi(*cache_keys).each do |key, id|
        next if id.nil?

        script_ids[key.delete_prefix(key_prefix)] = id
      end

      missing_hashes = scripts_by_hash.keys.reject { |script_hash| script_ids.key?(script_hash) }
      return [] if missing_hashes.empty?

      cache_entries = {}
      missing_hashes.each_slice(500) do |batch|
        script_class.where(script_hash: batch).pluck(:script_hash, :id).each do |script_hash, id|
          script_ids[script_hash] = id
          cache_entries["#{key_prefix}#{script_hash}"] = id
        end
      end

      new_scripts = {}
      missing_hashes.each do |script_hash|
        next if script_ids.key?(script_hash)

        new_scripts[script_hash] = script_attributes(scripts_by_hash[script_hash], script_hash)
      end

      if cache_entries.any?
        Rails.cache.write_multi(cache_entries)
        @redis_keys.concat(cache_entries.keys)
      end

      new_scripts.values
    end

    def record_script_ids(result, script_ids)
      return unless result.respond_to?(:columns) && result.respond_to?(:rows)

      columns = result.columns.map(&:to_s)
      id_index = columns.index("id")
      script_hash_index = columns.index("script_hash")
      return unless id_index && script_hash_index

      result.rows.each do |row|
        script_ids[row[script_hash_index]] = row[id_index]
      end
    end

    def lock_script_id_for(script_hash)
      @lock_script_ids ||= {}
      return @lock_script_ids[script_hash] if @lock_script_ids.key?(script_hash)

      script_id =
        Rails.cache.read("lock_script_hash_#{script_hash}") || LockScript.find_by(script_hash:)&.id
      @lock_script_ids[script_hash] = script_id if script_id
      script_id
    end

    def type_script_id_for(script_hash)
      @type_script_ids ||= {}
      return @type_script_ids[script_hash] if @type_script_ids.key?(script_hash)

      script_id =
        Rails.cache.read("type_script_hash_#{script_hash}") || TypeScript.find_by(script_hash:)&.id
      @type_script_ids[script_hash] = script_id if script_id
      script_id
    end

    def script_attributes(script, script_hash)
      {
        args: script.args,
        code_hash: script.code_hash,
        hash_type: script.hash_type,
        script_hash:,
      }
    end

    def build_cell_inputs(
      inputs, ckb_txs, local_block_id, cell_inputs_attributes, prev_cell_outputs_attributes,
input_capacities, tags, udt_address_ids, contained_udt_ids, contained_addr_ids, prev_outputs, token_transfer_ckb_tx_ids
    )
      tx_hashes = []
      inputs.each do |_, items|
        items.each do |input|
          tx_hashes << input.previous_output.tx_hash unless from_cell_base?(input)
        end
      end
      tx_hashes = tx_hashes.uniq

      previous_outputs = []
      tx_hashes.each_slice(500) do |batch|
        # CkbHashType treats every string starting with "0x" as a hex string.
        # Wrap the raw hash bytes in Binary::Data so a hash whose first bytes
        # are 0x30 0x78 (the ASCII "0x") is not decoded a second time.
        binary_hashes = batch.map do |tx_hash|
          ActiveModel::Type::Binary::Data.new(CKB::Utils.hex_to_bin(tx_hash))
        end
        previous_outputs.concat CellOutput.live.where(tx_hash: binary_hashes).to_a
      end
      previous_outputs_by_pointer =
        previous_outputs.index_by { |output| previous_output_key(output.tx_hash, output.cell_index) }

      inputs.each do |tx_index, items|
        items.each do |input|
          next if from_cell_base?(input)

          ckb_transaction_id = ckb_txs[tx_index]["id"]
          @tx_previous_outputs[ckb_transaction_id] ||= []
          previous_output = previous_outputs_by_pointer[previous_output_key(input.previous_output.tx_hash,
                                                                            input.previous_output.index)]
          unless previous_output
            # Fallback to the scalar lookup used before the batched query. This
            # also tells us whether the row is missing or the batched lookup
            # simply failed to find it.
            previous_output = CellOutput.live.find_by(
              tx_hash: input.previous_output.tx_hash,
              cell_index: input.previous_output.index,
            )
            if previous_output
              Rails.logger.warn(
                "[block-sync] previous output map miss resolved: " \
                "#{input.previous_output.tx_hash}##{input.previous_output.index}",
              )
            else
              any_status = CellOutput.find_by(
                tx_hash: input.previous_output.tx_hash,
                cell_index: input.previous_output.index,
              )
              Rails.logger.error(
                "[block-sync] previous output not found: " \
                "#{input.previous_output.tx_hash}##{input.previous_output.index}, " \
                "any_status=#{any_status&.status || 'missing'}",
              )
            end
          end
          @tx_previous_outputs[ckb_transaction_id] << previous_output
        end
      end

      tx_index = 0
      inputs.each do |tx_index, items|
        input_capacities[tx_index] = 0 if tx_index != 0
        items.each_with_index do |item, index|
          # attributes[0] is cell_inputs_attributes
          # attributes[1] is prev_cell_outputs_attributes
          # attributes[2] is previous_cell_output capacity
          # attributes[3] is previous_cell_output type_hash
          # attributes[4] is previous_cell address_id
          attributes = cell_input_attributes(item, ckb_txs[tx_index]["id"],
                                             local_block_id, prev_outputs, index)
          cell_inputs_attributes << attributes[:cell_input]
          previous_output = attributes[:previous_output]
          if previous_output.present?
            address_id = attributes[:address_id]
            capacity = attributes[:capacity]
            type_hash = attributes[:type_hash]
            addr_tx_changes[tx_index][address_id] -= capacity

            prev_cell_outputs_attributes << previous_output
            contained_addr_ids[tx_index] << address_id
            cell_type = previous_output[:cell_type].to_s
            if cell_type.in?(%w(nervos_dao_withdrawing))
              tags[tx_index] << "dao"
            elsif cell_type.in?(%w(m_nft_token nrc_721_token spore_cell did_cell))
              token_transfer_ckb_tx_ids << ckb_txs[tx_index]["id"]
            end

            case previous_output[:cell_type]
            when "udt"
              tags[tx_index] << "udt"
              udt_address_ids[tx_index] << address_id
              contained_udt_ids[tx_index] << Udt.where(type_hash:,
                                                       udt_type: "sudt").pick(:id)
            when "ssri"
              tags[tx_index] << "ssri"
              udt_address_ids[tx_index] << address_id
              contained_udt_ids[tx_index] << Udt.where(type_hash:,
                                                       udt_type: "ssri").pick(:id)

            when "omiga_inscription"
              tags[tx_index] << "omiga_inscription"
              udt_address_ids[tx_index] << address_id
              contained_udt_ids[tx_index] << Udt.where(type_hash:,
                                                       udt_type: "omiga_inscription").pick(:id)
            when "xudt"
              tags[tx_index] << "xudt"
              udt_address_ids[tx_index] << address_id
              contained_udt_ids[tx_index] << Udt.where(type_hash:,
                                                       udt_type: "xudt").pick(:id)

            when "xudt_compatible"
              tags[tx_index] << "xudt_compatible"
              udt_address_ids[tx_index] << address_id
              contained_udt_ids[tx_index] << Udt.where(type_hash:,
                                                       udt_type: "xudt_compatible").pick(:id)

            when "nrc_721_token"
              tags[tx_index] << "nrc_721_token"
              udt_address_ids[tx_index] << address_id
              contained_udt_ids[tx_index] << Udt.where(type_hash:,
                                                       udt_type: "nrc_721_token").pick(:id)
            end
            input_capacities[tx_index] += capacity.to_i if tx_index != 0
          end
        end
      end
    end

    def previous_output_key(tx_hash, index)
      [tx_hash.to_s.b, index.is_a?(String) ? index.hex : index]
    end

    def normalize_bytea_value(value)
      value = value.to_s
      value.start_with?("\\x") ? [value[2..]].pack("H*") : value
    end

    def build_cell_outputs!(
      node_block, outputs, ckb_txs, local_block, cell_outputs_attributes, output_capacities,
tags, udt_address_ids, contained_udt_ids, contained_addr_ids, token_transfer_ckb_tx_ids
    )
      @address_ids ||= {}
      @lock_script_ids ||= {}
      @redis_keys ||= []

      outputs.each do |tx_index, items|
        cell_index = 0
        # tx_index == 0 is cellbase, no need to calculate fee
        if tx_index != 0
          output_capacities[tx_index] = 0
        end
        items.each do |item|
          lock_script_hash = item.lock.compute_hash
          address_id = @address_ids[lock_script_hash]
          unless address_id
            address = Address.find_or_create_address(
              item.lock, local_block.timestamp,
              @lock_script_ids[lock_script_hash] || lock_script_id_for(lock_script_hash),
            )
            address_id = address.id
            @address_ids[lock_script_hash] = address_id
            address_key = "address_lock_hash_#{lock_script_hash}"
            Rails.cache.write(address_key, address_id)
            @redis_keys << address_key
          end

          addr_tx_changes[tx_index][address_id] += item.capacity
          type_script_hash = item.type&.compute_hash

          contained_addr_ids[tx_index] << address_id
          attr = cell_output_attributes(item, address_id, ckb_txs[tx_index], local_block, cell_index,
                                        node_block.transactions[tx_index].outputs_data[cell_index])
          cell_outputs_attributes << attr

          if attr[:cell_type].in?(%w(nervos_dao_deposit nervos_dao_withdrawing))
            tags[tx_index] << "dao"
          end

          if attr[:cell_type] == "udt"
            tags[tx_index] << "udt"
            udt_address_ids[tx_index] << address_id
            contained_udt_ids[tx_index] << Udt.where(
              type_hash: type_script_hash, udt_type: "sudt",
            ).pick(:id)
          elsif attr[:cell_type] == "ssri"
            tags[tx_index] << "ssri"
            udt_address_ids[tx_index] << address_id
            contained_udt_ids[tx_index] << Udt.where(
              type_hash: type_script_hash, udt_type: "ssri",
            ).pick(:id)
          elsif attr[:cell_type] == "omiga_inscription"
            tags[tx_index] << "omiga_inscription"
            udt_address_ids[tx_index] << address_id
            contained_udt_ids[tx_index] << Udt.where(
              type_hash: type_script_hash, udt_type: "omiga_inscription",
            ).pick(:id)
          elsif attr[:cell_type] == "xudt"
            tags[tx_index] << "xudt"
            udt_address_ids[tx_index] << address_id
            contained_udt_ids[tx_index] << Udt.where(
              type_hash: type_script_hash, udt_type: "xudt",
            ).pick(:id)
          elsif attr[:cell_type] == "xudt_compatible"
            tags[tx_index] << "xudt_compatible"
            udt_address_ids[tx_index] << address_id
            contained_udt_ids[tx_index] << Udt.where(
              type_hash: type_script_hash, udt_type: "xudt_compatible",
            ).pick(:id)
          elsif attr[:cell_type].in?(%w(m_nft_token nrc_721_token spore_cell did_cell))
            token_transfer_ckb_tx_ids << ckb_txs[tx_index]["id"]
          end

          output_capacities[tx_index] += item.capacity if tx_index != 0
          cell_index += 1
        end
      end
    end

    def cell_output_attributes(output, address_id, ckb_transaction, local_block, cell_index, output_data)
      lock_script_hash = output.lock.compute_hash
      lock_script_id = @lock_script_ids[lock_script_hash] || lock_script_id_for(lock_script_hash)

      type_script_hash = output.type&.compute_hash
      type_script_id = type_script_id_for(type_script_hash) if type_script_hash

      cell_type = cell_type(output.type, output_data).to_s
      udt_amount = udt_amount(cell_type, output_data, output.type&.args)
      if cell_type == "nrc_721_factory"
        update_nrc_factory_cell_info(output.type,
                                     output_data)
      end
      binary_data = CKB::Utils.hex_to_bin(output_data)
      attrs = {
        ckb_transaction_id: ckb_transaction["id"],
        capacity: output.capacity,
        occupied_capacity: CkbUtils.cal_cell_min_capacity(output.lock, output.type, binary_data),
        address_id: address_id,
        block_id: local_block.id,
        tx_hash: ckb_transaction["tx_hash"],
        cell_index:,
        cell_type:,
        block_timestamp: local_block.timestamp,
        type_hash: type_script_hash,
        dao: local_block.dao,
        lock_script_id: lock_script_id,
        type_script_id: type_script_id,
        udt_amount:,
        status: "live",
        created_at: Time.current,
        updated_at: Time.current,
      }

      if binary_data && binary_data.bytesize > 0
        attrs[:data_size] = binary_data.bytesize
        data_hash = CKB::Utils.bin_to_hex(CKB::Blake2b.digest(binary_data))
        attrs[:data_hash] = data_hash
        cell_datas[data_hash] = binary_data
      else
        attrs[:data_size] = 0
        attrs[:data_hash] = nil
      end
      attrs
    end

    def udt_amount(cell_type, output_data, type_script_args)
      case cell_type
      when "udt", "xudt", "xudt_compatible"
        CkbUtils.parse_udt_cell_data(output_data)
      when "omiga_inscription"
        CkbUtils.parse_omiga_inscription_data(output_data)[:mint_limit]
      when "m_nft_token"
        "0x#{type_script_args[-8..]}".hex
      end
    end

    def cell_input_attributes(input, ckb_transaction_id, local_block_id,
_prev_outputs, index = nil)
      if from_cell_base?(input)
        {
          cell_input: {
            ckb_transaction_id:,
            previous_tx_hash: nil,
            previous_index: 0,
            index:,
            since: input.since,
            block_id: local_block_id,
            from_cell_base: from_cell_base?(input),
            previous_cell_output_id: nil,
            cell_type: "normal",
            created_at: Time.current,
            updated_at: Time.current,
          },
        }
      else
        # previous_output = prev_outputs["#{input.previous_output.tx_hash}-#{input.previous_output.index}"]
        previous_output = @tx_previous_outputs[ckb_transaction_id].compact.find { |p_out| input.previous_output.tx_hash == p_out.tx_hash && p_out.cell_index == input.previous_output.index }
        unless previous_output
          raise "Previous cell output not found: #{input.previous_output.tx_hash}##{input.previous_output.index} " \
                "(block #{@local_block&.number})"
        end

        {
          cell_input: {
            ckb_transaction_id:,
            previous_tx_hash: input.previous_output.tx_hash,
            previous_index: input.previous_output.index,
            index:,
            since: input.since,
            block_id: local_block_id,
            from_cell_base: from_cell_base?(input),
            previous_cell_output_id: previous_output.id,
            cell_type: previous_output.cell_type,
            created_at: Time.current,
            updated_at: Time.current,
          },
          previous_output: {
            id: previous_output.id,
            cell_type: previous_output.cell_type,
            tx_hash: input.previous_output.tx_hash,
            cell_index: input.previous_output.index,
            status: 1,
            consumed_by_id: ckb_transaction_id,
            consumed_block_timestamp: @local_block.timestamp,
          },
          capacity: previous_output.capacity,
          type_hash: previous_output.type_hash,
          address_id: previous_output.address_id,
        }
      end
    end

    def build_ckb_transactions!(node_block, local_block, inputs, outputs, outputs_data, cell_deps)
      cycles = ApplicationRecord.benchmark("fetch_block_cycles") do
        CkbSync::Api.instance.get_block_cycles node_block.header.hash
      end
      ckb_transactions_attributes = []
      hashes = []
      header_deps = {}
      witnesses = {}
      node_block.transactions.each_with_index do |tx, tx_index|
        attrs = ckb_transaction_attributes(local_block, tx, tx_index)
        if cycles
          attrs[:cycles] = tx_index > 0 ? cycles[tx_index - 1]&.hex : nil
        end
        header_deps[tx.hash] = tx.header_deps
        cell_deps[tx.hash] = tx.cell_deps
        witnesses[tx.hash] = tx.witnesses
        ckb_transactions_attributes << attrs
        hashes << tx.hash

        inputs[tx_index] = tx.inputs
        outputs[tx_index] = tx.outputs
        outputs_data[tx_index] = tx.outputs_data
      end
      # First update status thus we can use upsert later. otherwise, we may not be able to
      # locate correct record according to tx_hash
      binary_hashes = CkbUtils.hexes_to_bins_sql(hashes)
      pending_txs = ApplicationRecord.benchmark("pending_txs_lookup") do
        CkbTransaction.where(tx_status: :pending).where("tx_hash IN (#{binary_hashes})").pluck(
          :tx_hash, :confirmation_time
        )
      end
      if pending_txs.size > 0
        ApplicationRecord.benchmark("pending_txs_update") do
          CkbTransaction.where(tx_status: :pending).where("tx_hash IN (#{binary_hashes})").update_all tx_status: "committed"
        end
      end
      txs = []
      ckb_transactions_attributes.each_slice(500) do |batch|
        results = ApplicationRecord.benchmark("ckb_transactions_import") do
          CkbTransaction.import(
            batch, validate: false,
            returning: %w(id tx_hash tx_index block_timestamp block_number created_at),
          )
        end.results
        txs.concat(results.map do |item|
          {
            "id" => item[0], "tx_hash" => item[1], "tx_index" => item[2], "block_timestamp" => item[3],
            "block_number" => item[4], "created_at" => item[5],
          }
        end)
      end

      if pending_txs.any?
        hash_to_pool_times = pending_txs.to_h
        confirmation_time_attrs =
          txs.select do |tx|
            tx["tx_hash"].tr("\\",
                             "0").in?(hash_to_pool_times.keys)
          end.map do |tx|
            {
              id: tx["id"], tx_status: :committed,
              confirmation_time: (tx["block_timestamp"].to_i - hash_to_pool_times[tx["tx_hash"].tr("\\", "0")].to_i) / 1000
            }
          end
        confirmation_time_attrs.each_slice(500) do |batch|
          ApplicationRecord.benchmark("confirmation_time_upsert") do
            CkbTransaction.upsert_all(batch, update_only: [:confirmation_time],
            unique_by: %i[id tx_status])
          end
        end
      end

      hash2id = {}
      txs.each do |t|
        hash2id["0#{t['tx_hash'][1..]}"] = t["id"]
      end

      # process header_deps
      header_deps_attrs = []
      header_deps.each do |tx_hash, deps|
        i = -1
        txid = hash2id[tx_hash]
        deps.each do |dep|
          i += 1
          header_deps_attrs << {
            ckb_transaction_id: txid,
            index: i,
            header_hash: dep,
          }
        end
      end
      if header_deps_attrs.present?
        ApplicationRecord.benchmark("header_deps_import") do
          HeaderDependency.import header_deps_attrs, validate: false, batch_size: 500
        end
      end

      # process witnesses
      witnesses_attrs = []
      witnesses.each do |tx_hash, w|
        i = -1
        txid = hash2id[tx_hash]
        w.each do |witness|
          i += 1
          if witness
            witnesses_attrs << {
              ckb_transaction_id: txid,
              index: i,
              data: witness,
            }
          end
        end
      end

      if witnesses_attrs.present?
        ApplicationRecord.benchmark("witnesses_import") do
          Witness.import witnesses_attrs, validate: false, batch_size: 500
        end
      end

      txs
    end

    def ckb_transaction_attributes(local_block, tx, tx_index)
      {
        tx_status: "committed",
        block_id: local_block.id,
        tx_hash: tx.hash,
        # cell_deps: tx.cell_deps,
        # header_deps: tx.header_deps,
        version: tx.version,
        block_number: local_block.number,
        block_timestamp: local_block.timestamp,
        transaction_fee: 0,
        # witnesses: tx.witnesses,
        is_cellbase: tx_index.zero?,
        live_cell_changes: live_cell_changes(tx, tx_index),
        bytes: CkbSync::TransactionSizeCalculator.serialized_size_in_block(tx),
        tx_index:,
      }
    end

    def build_uncle_blocks!(node_block, local_block_id)
      node_block.uncles.each do |uncle_block|
        header = uncle_block.header
        epoch_info = CkbUtils.parse_epoch_info(header)
        UncleBlock.create_with(
          compact_target: header.compact_target,
          difficulty: CkbUtils.compact_to_difficulty(header.compact_target),
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
          dao: header.dao,
        ).find_or_create_by!(
          block_id: local_block_id,
          block_hash: header.hash,
        )
      end
    end

    def build_block!(node_block)
      block = nil

      self.class.trace_execution_scoped(["ckb_sync/new_node_data_processor/build_block"]) do
        header = node_block.header
        epoch_info = CkbUtils.parse_epoch_info(header)
        cellbase = node_block.transactions.first

        generate_address_in_advance(cellbase, header.timestamp)
        block_cell_consumed = CkbUtils.block_cell_consumed(node_block.transactions)
        total_cell_capacity = CkbUtils.total_cell_capacity(node_block.transactions)
        miner_hash = CkbUtils.miner_hash(cellbase)
        miner_lock_hash = CkbUtils.miner_lock_hash(cellbase)
        base_reward = CkbUtils.base_reward(header.number, epoch_info.number)
        block = Block.create_with(
          compact_target: header.compact_target,
          difficulty: CkbUtils.compact_to_difficulty(header.compact_target),
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
          total_cell_capacity:,
          miner_hash:,
          miner_lock_hash:,
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
          extension: node_block.extension,
          median_timestamp: get_median_timestamp(header.hash),
        ).find_or_create_by!(
          block_hash: header.hash,
          number: header.number,
        )
      end
      block
    end

    def get_median_timestamp(block_hash)
      response = CkbSync::Api.instance.directly_single_call_rpc method: "get_block_median_time",
                                                                params: [block_hash]
      response["result"].to_i(16)
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

      script_hash = lock_script.compute_hash
      key = "lock_script_hash_#{script_hash}"
      lock_script_id = Rails.cache.read(key)
      
      unless lock_script_id
        lock_script_id = LockScript.find_or_create_by(
          code_hash: lock_script.code_hash,
          hash_type: lock_script.hash_type,
          args: lock_script.args,
          script_hash: script_hash
        ).id
        Rails.cache.write(key, lock_script_id)
        @redis_keys << key
      end
      unless Rails.cache.exist?("address_lock_hash_#{script_hash}")
        address = Address.find_or_create_address(lock_script, block_timestamp, lock_script_id)
        Rails.cache.write("address_lock_hash_#{script_hash}", address.id)
        @redis_keys << "address_lock_hash_#{script_hash}"
      end
    end

    def cell_type(type_script, output_data = nil)
      CkbUtils.cell_type(type_script, output_data)
    end

    def forked?(target_block, local_tip_block)
      return false if local_tip_block.blank?

      target_block.header.parent_hash != local_tip_block.block_hash
    end

    def update_nrc_factory_cell_info(type_script, output_data)
      factory_cell = NrcFactoryCell.find_or_create_by(
        code_hash: type_script.code_hash,
        hash_type: type_script.hash_type,
        args: type_script.args,
      )
      parsed_factory_data = CkbUtils.parse_nrc_721_factory_data(output_data)
      factory_cell.update(
        name: CkbUtils.sanitize_string(parsed_factory_data.name),
        symbol: CkbUtils.sanitize_string(parsed_factory_data.symbol),
        base_token_uri: CkbUtils.sanitize_string(parsed_factory_data.base_token_uri),
        extra_data: CkbUtils.sanitize_string(parsed_factory_data.extra_data),
      )
    end

    def benchmark(method_name = nil, *args)
      ApplicationRecord.benchmark method_name do
        send(method_name, *args)
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
