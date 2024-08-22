require "newrelic_rpm"
require "new_relic/agent/method_tracer"

module CkbSync
  class NewNodeDataProcessor
    include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
    include NewRelic::Agent::MethodTracer
    include Redis::Objects

    value :reorg_started_at, global: true
    attr_accessor :local_tip_block, :pending_raw_block, :ckb_txs, :target_block, :addrs_changes,
                  :outputs, :inputs, :outputs_data, :udt_address_ids, :contained_address_ids,
                  :dao_address_ids, :contained_udt_ids, :cell_datas, :enable_cota, :token_transfer_ckb_tx_ids

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
      target_block_number = local_tip_block.present? ? local_tip_block.number + 1 : 0
      puts "Offset #{@offset}" if @offset > 0
      return if target_block_number > tip_block_number - @offset.to_i

      target_block = CkbSync::Api.instance.get_block_by_number(target_block_number)
      if !forked?(target_block, local_tip_block)
        Rails.logger.error "process_block: #{target_block_number}"
        res =
          ApplicationRecord.cache do
            process_block(target_block)
          end
        reorg_started_at.delete
        res
      else
        self.reorg_started_at = Time.now
        res = RevertBlockJob.perform_now(local_tip_block)
        reorg_started_at.delete
        res
      end
    rescue StandardError => e
      Rails.logger.error e.message
      puts e.backtrace.join("\n")
      raise e
    end

    def process_block(node_block, refresh_balance: true)
      local_block = nil

      ApplicationRecord.transaction do
        # build node data
        local_block = @local_block = build_block!(node_block)
        local_cache.write("BlockNumber", local_block.number)
        build_uncle_blocks!(node_block, local_block.id)
        inputs = @inputs = {}
        outputs = @outputs = {}
        outputs_data = @outputs_data = {}
        @ckb_txs = build_ckb_transactions!(node_block, local_block, inputs, outputs, outputs_data).to_a
        benchmark :build_udts!, local_block, outputs, outputs_data

        tags = []
        @udt_address_ids = udt_address_ids = []
        @dao_address_ids = dao_address_ids = []
        @contained_udt_ids = contained_udt_ids = []
        @contained_address_ids = contained_address_ids = []
        @token_transfer_ckb_tx_ids = token_transfer_ckb_tx_ids = Set.new

        benchmark :process_ckb_txs, node_block, ckb_txs, contained_address_ids,
                  contained_udt_ids, dao_address_ids, tags, udt_address_ids
        addrs_changes = Hash.new { |hash, key| hash[key] = {} }

        input_capacities, output_capacities = benchmark :build_cells_and_locks!, local_block, node_block, ckb_txs, inputs, outputs,
                                                        tags, udt_address_ids, dao_address_ids, contained_udt_ids, contained_address_ids, addrs_changes, token_transfer_ckb_tx_ids

        # update explorer data
        benchmark :update_ckb_txs_rel_and_fee, ckb_txs, tags, input_capacities, output_capacities, udt_address_ids,
                  dao_address_ids, contained_udt_ids, contained_address_ids
        benchmark :update_block_info!, local_block
        benchmark :update_block_reward_info!, local_block
        benchmark :update_mining_info, local_block
        benchmark :update_table_records_count, local_block
        benchmark :update_or_create_udt_accounts!, local_block
        # maybe can be changed to asynchronous update
        benchmark :process_dao_events!, local_block
        benchmark :update_addresses_info, addrs_changes, local_block, refresh_balance
      end

      async_update_udt_infos(local_block)
      flush_inputs_outputs_caches(local_block)
      generate_statistics_data(local_block)
      generate_deployed_cells_and_referring_cells(local_block)
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

    def generate_deployed_cells_and_referring_cells(local_block)
      GenerateCellDependenciesWorker.perform_async(local_block.id)
    end

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
      node_block, ckb_txs, contained_address_ids, contained_udt_ids, dao_address_ids, tags,
udt_address_ids
    )
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
      new_dao_depositors = {}
      dao_contract = DaoContract.default_contract
      process_deposit_dao_events!(local_block, new_dao_depositors, dao_contract)
      process_withdraw_dao_events!(local_block, new_dao_depositors, dao_contract)
      process_interest_dao_events!(local_block, dao_contract)
      build_new_dao_depositor_events!(local_block, new_dao_depositors, dao_contract)

      # update dao contract ckb_transactions_count
      dao_contract.increment!(:ckb_transactions_count,
                              local_block.ckb_transactions.where(
                                "tags @> array[?]::varchar[]", ["dao"]
                              ).count)
    end

    def build_new_dao_depositor_events!(local_block, new_dao_depositors, dao_contract)
      new_dao_events_attributes = []
      new_dao_depositors.each do |address_id, ckb_transaction_id|
        new_dao_events_attributes << {
          block_id: local_block.id, ckb_transaction_id:, address_id:, event_type: "new_dao_depositor",
          value: 1, status: "processed", contract_id: dao_contract.id, block_timestamp: local_block.timestamp,
          created_at: Time.current, updated_at: Time.current
        }
      end

      if new_dao_events_attributes.present?
        DaoEvent.insert_all!(new_dao_events_attributes)
        dao_contract.update!(
          total_depositors_count: dao_contract.total_depositors_count + new_dao_events_attributes.size,
          depositors_count: dao_contract.depositors_count + new_dao_events_attributes.size,
        )
        address_ids = []
        new_dao_events_attributes.each do |dao_event_attr|
          address_ids << dao_event_attr[:address_id]
        end
        Address.where(id: address_ids).update_all(is_depositor: true)
      end
    end

    # Process DAO withdraw
    # Warning：because DAO withdraw is also a cell, to the destination address of withdraw is the address of the withdraw cell output.
    # So it's possible that the deposit address is different with the withdraw address.
    def process_withdraw_dao_events!(local_block, _new_dao_depositors,
dao_contract)
      dao_contract = DaoContract.default_contract
      withdraw_amount = 0
      withdraw_transaction_ids = Set.new
      addrs_withdraw_info = {}
      claimed_compensation = 0
      take_away_all_deposit_count = 0
      # When DAO Deposit Cell appears in cell inputs, the transaction is DAO withdrawal
      local_block.cell_inputs.nervos_dao_deposit.select(:id, :ckb_transaction_id,
                                                        :previous_cell_output_id).find_in_batches do |dao_inputs|
        dao_events_attributes = []
        dao_inputs.each do |dao_input|
          previous_cell_output =
            CellOutput.
              where(id: dao_input.previous_cell_output_id).
              select(:address_id, :ckb_transaction_id, :dao, :cell_index, :capacity, :occupied_capacity).
              take!
          address = previous_cell_output.address
          address.dao_deposit ||= 0
          if addrs_withdraw_info.key?(address.id)
            addrs_withdraw_info[address.id][:dao_deposit] -= previous_cell_output.capacity
          else
            addrs_withdraw_info[address.id] = {
              dao_deposit: address.dao_deposit.to_i - previous_cell_output.capacity,
              is_depositor: address.is_depositor,
              created_at: address.created_at,
            }
          end
          if addrs_withdraw_info[address.id][:dao_deposit] < 0
            addrs_withdraw_info[address.id][:dao_deposit] = 0
          end
          dao_events_attributes << {
            ckb_transaction_id: dao_input.ckb_transaction_id,
            block_id: local_block.id,
            block_timestamp: local_block.timestamp,
            address_id: previous_cell_output.address_id,
            event_type: "withdraw_from_dao",
            value: previous_cell_output.capacity,
            status: "processed",
            contract_id: dao_contract.id, created_at: Time.current,
            updated_at: Time.current
          }
          address_dao_deposit = Address.where(id: previous_cell_output.address_id).pick(:dao_deposit)
          if address_dao_deposit && (address_dao_deposit - previous_cell_output.capacity).zero?
            take_away_all_deposit_count += 1
            addrs_withdraw_info[address.id][:is_depositor] = false
            dao_events_attributes << {
              ckb_transaction_id: dao_input.ckb_transaction_id,
              block_id: local_block.id,
              block_timestamp: local_block.timestamp,
              address_id: previous_cell_output.address_id,
              event_type: "take_away_all_deposit",
              value: 1,
              status: "processed",
              contract_id: dao_contract.id,
              created_at: Time.current,
              updated_at: Time.current,
            }
          else
            puts "Cannot find address dao for #{previous_cell_output.address_id}"
          end
          withdraw_amount += previous_cell_output.capacity
          withdraw_transaction_ids << dao_input.ckb_transaction_id
        end
        DaoEvent.insert_all!(dao_events_attributes) if dao_events_attributes.present?
      end

      # update dao contract info
      dao_contract.update!(
        total_deposit: dao_contract.total_deposit - withdraw_amount,
        withdraw_transactions_count: dao_contract.withdraw_transactions_count + withdraw_transaction_ids.size,
        depositors_count: dao_contract.depositors_count - take_away_all_deposit_count,
      )
      update_addresses_dao_info(addrs_withdraw_info)
    end

    # Process the interest of DAO deposit
    # After the previous withdraw step, destruct the nervos_dao_withdraw cell，returning free CKB，plus interest
    # eg. https://explorer.nervos.org/transaction/0xfbaaa415c34542148a15ead5c9f3e1e2cefd39ace57107244a1404ba0d56b8f1
    def process_interest_dao_events!(local_block, dao_contract)
      addrs_withdraw_info = {}
      claimed_compensation = 0
      local_block.cell_inputs.nervos_dao_withdrawing.select(:id, :ckb_transaction_id, :block_id,
                                                            :previous_cell_output_id).find_in_batches do |dao_inputs|
        dao_events_attributes = []
        dao_inputs.each do |dao_input|
          previous_cell_output = CellOutput.
            where(id: dao_input.previous_cell_output_id).
            select(:address_id, :block_id, :ckb_transaction_id, :dao, :cell_index, :capacity, :occupied_capacity).
            take!
          address = previous_cell_output.address
          interest = CkbUtils.dao_interest(previous_cell_output)
          if addrs_withdraw_info.key?(address.id)
            addrs_withdraw_info[address.id][:interest] += interest
          else
            addrs_withdraw_info[address.id] = {
              interest: address.interest.to_i + interest,
              is_depositor: address.is_depositor,
              created_at: address.created_at,
            }
          end
          # addrs_withdraw_info[address.id][:dao_deposit] = 0 if addrs_withdraw_info[address.id][:dao_deposit] < 0
          dao_events_attributes << {
            ckb_transaction_id: dao_input.ckb_transaction_id,
            block_id: local_block.id,
            block_timestamp: local_block.timestamp,
            address_id: previous_cell_output.address_id,
            event_type: "issue_interest",
            value: interest,
            status: "processed",
            contract_id: dao_contract.id,
            created_at: Time.current,
            updated_at: Time.current,
          }
          claimed_compensation += interest
        end
        DaoEvent.insert_all!(dao_events_attributes) if dao_events_attributes.present?
      end
      # update dao contract info
      dao_contract.update!(
        claimed_compensation: dao_contract.claimed_compensation + claimed_compensation,
      )
      update_addresses_dao_info(addrs_withdraw_info)
    end

    def process_deposit_dao_events!(local_block, new_dao_depositors, dao_contract)
      deposit_amount = 0
      deposit_transaction_ids = Set.new
      addresses_deposit_info = {}
      # build deposit dao events
      local_block.cell_outputs.nervos_dao_deposit.select(:id, :address_id, :capacity,
                                                         :ckb_transaction_id).find_in_batches do |dao_outputs|
        deposit_dao_events_attributes = []
        dao_outputs.each do |dao_output|
          address = dao_output.address
          address.dao_deposit ||= 0
          if addresses_deposit_info.key?(address.id)
            addresses_deposit_info[address.id][:dao_deposit] += dao_output.capacity
          else
            addresses_deposit_info[address.id] =
              {
                dao_deposit: address.dao_deposit.to_i + dao_output.capacity,
                interest: address.interest,
                is_depositor: address.is_depositor,
                created_at: address.created_at,
              }
          end
          if address.dao_deposit.zero? && !new_dao_depositors.key?(address.id)
            new_dao_depositors[address.id] = dao_output.ckb_transaction_id
          end
          deposit_amount += dao_output.capacity
          deposit_transaction_ids << dao_output.ckb_transaction_id
          deposit_dao_events_attributes << {
            ckb_transaction_id: dao_output.ckb_transaction_id,
            block_id: local_block.id,
            address_id: address.id,
            event_type: "deposit_to_dao",
            value: dao_output.capacity,
            status: "processed",
            contract_id: dao_contract.id,
            block_timestamp: local_block.timestamp,
            created_at: Time.current,
            updated_at: Time.current,
          }
        end
        DaoEvent.insert_all!(deposit_dao_events_attributes) if deposit_dao_events_attributes.present?
      end
      # update dao contract info
      dao_contract.update!(
        total_deposit: dao_contract.total_deposit + deposit_amount,
        deposit_transactions_count: dao_contract.deposit_transactions_count + deposit_transaction_ids.size,
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
          created_at: address_info[:created_at],
          updated_at: Time.current,
        }
      end
      Address.upsert_all(addresses_deposit_attributes) if addresses_deposit_attributes.present?
    end

    def update_or_create_udt_accounts!(local_block)
      new_udt_accounts_attributes = Set.new
      udt_accounts_attributes = Set.new
      local_block.cell_outputs.select(:id, :address_id, :type_hash, :cell_type,
                                      :type_script_id).each do |udt_output|
        next unless udt_output.cell_type.in?(%w(udt m_nft_token nrc_721_token
                                                spore_cell did_cell omiga_inscription xudt xudt_compatible))

        address = Address.find(udt_output.address_id)
        udt_type = udt_type(udt_output.cell_type)
        udt_account = address.udt_accounts.where(type_hash: udt_output.type_hash, udt_type:).select(:id,
                                                                                                    :created_at).first
        amount = udt_account_amount(udt_type, udt_output.type_hash, address)
        nft_token_id =
          case udt_type
          when "nrc_721_token"
            CkbUtils.parse_nrc_721_args(udt_output.type_script.args).token_id
          when "spore_cell", "did_cell"
            udt_output.type_script.args.hex
          end
        udt = Udt.where(type_hash: udt_output.type_hash, udt_type:).select(:id, :udt_type, :full_name,
                                                                           :symbol, :decimal, :published, :code_hash, :type_hash, :created_at).take!
        if udt_account.present?
          udt_accounts_attributes << { id: udt_account.id, amount:,
                                       created_at: udt.created_at }
        else
          new_udt_accounts_attributes << {
            address_id: udt_output.address_id, udt_type: udt.udt_type, full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal,
            published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount:, udt_id: udt.id, nft_token_id:
          }
        end
      end

      local_block.ckb_transactions.pluck(:id).each do |tx_id| # iterator over each tx id for better sql performance
        CellOutput.where(consumed_by_id: tx_id).select(:id, :address_id,
                                                       :type_hash, :cell_type).each do |udt_output|
          next unless udt_output.cell_type.in?(%w(udt m_nft_token nrc_721_token
                                                  spore_cell did_cell omiga_inscription xudt xudt_compatible))

          address = Address.find(udt_output.address_id)
          udt_type = udt_type(udt_output.cell_type)
          udt_account = address.udt_accounts.where(type_hash: udt_output.type_hash, udt_type:).select(:id,
                                                                                                      :created_at).first
          amount = udt_account_amount(udt_type, udt_output.type_hash, address)
          udt = Udt.where(type_hash: udt_output.type_hash, udt_type:).select(:id, :udt_type, :full_name,
                                                                             :symbol, :decimal, :published, :code_hash, :type_hash, :created_at).take!
          if udt_account.present?
            case udt_type
            when "sudt", "omiga_inscription", "xudt", "xudt_compatible"
              udt_accounts_attributes << { id: udt_account.id, amount:,
                                           created_at: udt.created_at }
            when "m_nft_token", "nrc_721_token", "spore_cell", "did_cell"
              udt_account.destroy unless address.cell_outputs.live.where(cell_type: udt_type).where(type_hash: udt_output.type_hash).exists?
            end
          end
        end
      end

      if new_udt_accounts_attributes.present?
        UdtAccount.insert_all!(new_udt_accounts_attributes.map! do |attr|
                                 attr.merge!(created_at: Time.current,
                                             updated_at: Time.current)
                               end)
      end
      if udt_accounts_attributes.present?
        UdtAccount.upsert_all(udt_accounts_attributes.map! do |attr|
                                attr.merge!(updated_at: Time.current)
                              end)
      end
    end

    def udt_type(cell_type)
      cell_type == "udt" ? "sudt" : cell_type
    end

    def udt_account_amount(udt_type, type_hash, address)
      case udt_type
      when "sudt"
        address.cell_outputs.live.udt.where(type_hash:).sum(:udt_amount)
      when "xudt", "xudt_compatible", "omiga_inscription", "m_nft_token", "spore_cell", "did_cell"
        address.cell_outputs.live.where(cell_type: udt_type).where(type_hash:).sum(:udt_amount)
      else
        0
      end
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

    def update_addresses_info(addrs_change, local_block, refresh_balance)
      return unless refresh_balance

      ### because `upsert` don't validate record, so it may pass invalid data into database.
      ### here we use one by one update (maybe slower)
      addrs_change.each do |addr_id, values|
        addr = Address.find addr_id
        check_invalid_address(addr)

        balance_diff = values[:balance_diff]
        balance_occupied_diff = values[:balance_occupied_diff].presence || 0
        live_cells_diff = values[:cells_diff]
        dao_txs_count = values[:dao_txs].present? ? values[:dao_txs].size : 0
        ckb_txs_count = values[:ckb_txs].present? ? values[:ckb_txs].size : 0

        addr.update!(
          balance: addr.balance + balance_diff,
          balance_occupied: addr.balance_occupied + balance_occupied_diff,
          ckb_transactions_count: addr.ckb_transactions_count + ckb_txs_count,
          live_cells_count: addr.live_cells_count + live_cells_diff,
          dao_transactions_count: addr.dao_transactions_count + dao_txs_count,
        )

        save_address_block_snapshot!(addr, local_block)
      end
    end

    def save_address_block_snapshot!(addr, local_block)
      AddressBlockSnapshot.create_with(
        block_number: local_block.number,
        final_state: {
          balance: addr.balance,
          balance_occupied: addr.balance_occupied,
          ckb_transactions_count: addr.ckb_transactions_count,
          live_cells_count: addr.live_cells_count,
          dao_transactions_count: addr.dao_transactions_count,
        },
      ).find_or_create_by!(
        address_id: addr.id,
        block_id: local_block.id,
      )
    end

    def update_block_info!(local_block)
      local_block.update!(
        total_transaction_fee: local_block.ckb_transactions.sum(:transaction_fee),
        ckb_transactions_count: local_block.ckb_transactions.count,
        live_cell_changes: local_block.ckb_transactions.sum(&:live_cell_changes),
        address_ids: local_block.ckb_transactions.map(&:contained_address_ids).flatten.uniq,
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
                attrs[:is_repeated_symbol] = OmigaInscriptionInfo.where(symbol: info[:symbol].strip).exists?
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
            nft_token_attr = { full_name: nil, icon_file: nil,
                               published: false, symbol: nil, decimal: nil, nrc_factory_cell_id: nil }
            issuer_address = CkbUtils.generate_address(output.lock, CKB::Address::Version::CKB2021)
            case cell_type
            when "m_nft_token"
              m_nft_class_type = TypeScript.where(code_hash: CkbSync::Api.instance.token_class_script_code_hash,
                                                  args: output.type.args[0..49]).first
              if m_nft_class_type.present?
                m_nft_class_cell = m_nft_class_type.cell_outputs.last
                parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
                TokenCollection.find_or_create_by(
                  standard: "m_nft",
                  name: parsed_class_data.name,
                  cell_id: m_nft_class_cell.id,
                  block_timestamp: m_nft_class_cell.block_timestamp,
                  icon_url: parsed_class_data.renderer,
                  creator_id: m_nft_class_cell.address_id,
                )

                nft_token_attr[:full_name] = parsed_class_data.name
                nft_token_attr[:icon_file] = parsed_class_data.renderer
                nft_token_attr[:published] = true
              end
            when "spore_cell", "did_cell"
              nft_token_attr[:published] = true
              parsed_spore_cell = CkbUtils.parse_spore_cell_data(outputs_data[tx_index][index])
              if parsed_spore_cell[:cluster_id].present?
                binary_hashes = CkbUtils.hexes_to_bins_sql(CkbSync::Api.instance.spore_cluster_code_hashes)
                spore_cluster_type_ids = TypeScript.where("code_hash IN (#{binary_hashes})").where(hash_type: "data1", args: parsed_spore_cell[:cluster_id]).pluck(:id)
                if spore_cluster_type_ids.present?
                  spore_cluster_cell = CellOutput.live.where(type_script_id: spore_cluster_type_ids).last
                  parsed_cluster_data = CkbUtils.parse_spore_cluster_data(spore_cluster_cell.data)
                  nft_token_attr[:full_name] = parsed_cluster_data[:name]
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
              nft_token_attr[:full_name] = info[:name]
              nft_token_attr[:symbol] = info[:symbol]
              nft_token_attr[:decimal] = info[:decimal]
              nft_token_attr[:published] = true
            when "xudt", "xudt_compatible"
              if output.type.args.length == 66
                issuer_address = Address.find_by(lock_hash: output.type.args[0..65])&.address_hash
              end
              items.each_with_index do |output, index|
                if output.type&.code_hash == CkbSync::Api.instance.unique_cell_code_hash
                  info = CkbUtils.parse_unique_cell(outputs_data[tx_index][index])
                  nft_token_attr[:full_name] = info[:name]
                  nft_token_attr[:symbol] = info[:symbol]
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
        returning_attrs = Udt.insert_all!(udts_attributes.map! do |attr|
                                            attr.merge!(created_at: Time.current, updated_at: Time.current)
                                          end, returning: %w[id udt_type type_hash])
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
      ckb_txs, tags, input_capacities, output_capacities, udt_address_ids,
dao_address_ids, contained_udt_ids, contained_addr_ids
    )
      ckb_transactions_attributes = []
      tx_index = 0
      full_tx_address_ids = []
      full_tx_udt_ids = []
      full_dao_address_ids = []
      full_udt_address_ids = []
      ckb_txs.each do |tx|
        tx_id = tx["id"]
        full_tx_address_ids +=
          contained_addr_ids[tx_index].to_a.map do |a|
            { address_id: a, ckb_transaction_id: tx_id }
          end
        full_dao_address_ids += dao_address_ids[tx_index].to_a.map do |a|
          { address_id: a, ckb_transaction_id: tx_id }
        end
        full_tx_udt_ids += contained_udt_ids[tx_index].to_a.map do |u|
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
                                           output_capacities[tx_index])
            end,
          created_at: tx["created_at"],
          updated_at: Time.current,
        }

        # binding.pry if attr[:transaction_fee] < 0
        ckb_transactions_attributes << attr
        tx_index += 1
      end

      if ckb_transactions_attributes.present?
        CkbTransaction.upsert_all(ckb_transactions_attributes,
                                  unique_by: %i[id tx_status])
      end
      if full_tx_address_ids.present?
        AccountBook.upsert_all full_tx_address_ids,
                               unique_by: %i[address_id ckb_transaction_id]
      end
      if full_tx_udt_ids.present?
        UdtTransaction.upsert_all full_tx_udt_ids,
                                  unique_by: %i[udt_id
                                                ckb_transaction_id]
      end
      if full_dao_address_ids.present?
        AddressDaoTransaction.upsert_all full_dao_address_ids,
                                         unique_by: %i[address_id
                                                       ckb_transaction_id]
      end
      if full_udt_address_ids.present?
        AddressUdtTransaction.upsert_all full_udt_address_ids,
                                         unique_by: %i[address_id
                                                       ckb_transaction_id]
      end
    end

    def build_cells_and_locks!(
      local_block, node_block, ckb_txs, inputs, outputs, tags, udt_address_ids,
      dao_address_ids, contained_udt_ids, contained_addr_ids, addrs_changes, token_transfer_ckb_tx_ids
    )
      cell_outputs_attributes = []
      cell_inputs_attributes = []
      prev_cell_outputs_attributes = []
      input_capacities = []
      output_capacities = []
      lock_scripts_attributes, type_scripts_attributes = build_scripts(outputs)
      lock_script_ids = []
      type_script_ids = []

      if lock_scripts_attributes.present?
        lock_scripts_attributes.map! do |attr|
          attr.merge!(created_at: Time.current, updated_at: Time.current)
        end
        lock_script_ids = LockScript.insert_all!(lock_scripts_attributes).map do |e|
          e["id"]
        end

        lock_script_ids.each do |lock_script_id|
          lock_script = LockScript.find lock_script_id
          contract = Contract.find_by code_hash: lock_script.code_hash
          temp_hash = { script_hash: lock_script&.script_hash, is_contract: false }
          if contract
            temp_hash = temp_hash.merge is_contract: true, contract_id: contract.id
          else
            contract = Contract.create code_hash: lock_script.script_hash
            temp_hash = temp_hash.merge contract_id: contract.id
          end
          script = Script.find_or_create_by temp_hash
          lock_script.update script_id: script.id
        end
      end

      if type_scripts_attributes.present?
        type_scripts_attributes.map! do |attr|
          attr.merge!(created_at: Time.current, updated_at: Time.current)
        end
        type_script_ids = TypeScript.insert_all!(type_scripts_attributes).map do |e|
          e["id"]
        end

        type_script_ids.each do |type_script_id|
          type_script = TypeScript.find(type_script_id)
          temp_hash = { script_hash: type_script&.script_hash, is_contract: false }
          contract = Contract.find_by code_hash: type_script.code_hash
          if contract
            temp_hash = temp_hash.merge is_contract: true, contract_id: contract.id
          else
            contract = Contract.create code_hash: type_script.script_hash
            temp_hash = temp_hash.merge contract_id: contract.id
          end
          script = Script.find_or_create_by temp_hash
          type_script.update script_id: script.id
        end
      end
      build_addresses!(outputs, local_block)
      # prepare script ids for insert cell_outputs
      prepare_script_ids(outputs)
      build_cell_outputs!(node_block, outputs, ckb_txs, local_block, cell_outputs_attributes, output_capacities, tags,
                          udt_address_ids, dao_address_ids, contained_udt_ids, contained_addr_ids, addrs_changes, token_transfer_ckb_tx_ids)
      if cell_outputs_attributes.present?
        tx_hashes = cell_outputs_attributes.map { |attr| attr[:tx_hash] }
        binary_hashes = CkbUtils.hexes_to_bins_sql(tx_hashes)
        CellOutput.pending.where("tx_hash IN (#{binary_hashes})").update_all(status: :live)
        id_hashes = CellOutput.upsert_all(cell_outputs_attributes, unique_by: %i[tx_hash cell_index status],
                                                                   returning: %i[id data_hash])
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
          CellDatum.upsert_all(cell_data_attrs, unique_by: [:cell_output_id])
        end
      end

      prev_outputs = nil
      build_cell_inputs(inputs, ckb_txs, local_block.id, cell_inputs_attributes, prev_cell_outputs_attributes,
                        input_capacities, tags, udt_address_ids, dao_address_ids, contained_udt_ids, contained_addr_ids,
                        prev_outputs, addrs_changes, token_transfer_ckb_tx_ids)

      CellInput.upsert_all(cell_inputs_attributes,
                           unique_by: %i[ckb_transaction_id index])
      if prev_cell_outputs_attributes.present?
        cell_ouput_ids = prev_cell_outputs_attributes.map { |attr| attr[:id] }
        CellOutput.live.where(id: cell_ouput_ids).update_all(status: :dead)
        CellOutput.upsert_all(prev_cell_outputs_attributes,
                              unique_by: %i[tx_hash cell_index status],
                              record_timestamps: true)
      end

      ScriptTransaction.create_from_scripts TypeScript.where(id: type_script_ids)
      ScriptTransaction.create_from_scripts LockScript.where(id: lock_script_ids)

      [input_capacities, output_capacities]
    end

    def build_addresses!(outputs, local_block)
      block_number = local_cache.read("BlockNumber")
      outputs.each_value do |items|
        items.each do |item|
          address =
            local_cache.fetch("NodeData/Address/#{item.lock.code_hash}-#{item.lock.hash_type}-#{item.lock.args}") do
              lock_script = LockScript.find_by(code_hash: item.lock.code_hash, hash_type: item.lock.hash_type, args: item.lock.args)
              Address.find_or_create_address(item.lock, local_block.timestamp, lock_script.id)
            end
          local_cache.push(
            "NodeData/#{block_number}/ContainedAddresses",
            Address.new(id: address.id, created_at: address.created_at),
          )
        end
      end
    end

    def prepare_script_ids(outputs)
      outputs.each_value do |items|
        items.each do |output|
          local_cache.fetch("NodeData/LockScript/#{output.lock.code_hash}-#{output.lock.hash_type}-#{output.lock.args}") do
            # TODO use LockScript.where(script_hash: output.lock.compute_hash).select(:id)&.first replace search by code_hash, hash_type and args query after script_hash has been filled
            LockScript.where(code_hash: output.lock.code_hash, hash_type: output.lock.hash_type,
                             args: output.lock.args).take!
          end
          if output.type.present?
            local_cache.fetch("NodeData/TypeScript/#{output.type.code_hash}-#{output.type.hash_type}-#{output.type.args}") do
              # TODO use TypeScript.where(script_hash: output.type.compute_hash).select(:id)&.first replace search by code_hash, hash_type and args query after script_hash has been filled
              TypeScript.where(code_hash: output.type.code_hash, hash_type: output.type.hash_type,
                               args: output.type.args).take!
            end
          end
        end
      end
    end

    def build_scripts(outputs)
      locks_attributes = Set.new
      types_attributes = Set.new
      block_number = local_cache.read("BlockNumber")
      outputs.each_value do |items|
        items.each do |output|
          lock_cache_key = "NodeData/#{block_number}/Lock/#{output.lock.code_hash}-#{output.lock.hash_type}-#{output.lock.args}"
          unless local_cache.read(lock_cache_key)
            script_hash = output.lock.compute_hash
            unless LockScript.where(code_hash: output.lock.code_hash, hash_type: output.lock.hash_type, args: output.lock.args).exists?
              locks_attributes << script_attributes(output.lock, script_hash)
              local_cache.write(lock_cache_key, true)
            end
          end

          if output.type.present?
            type_cache_key = "NodeData/#{block_number}/Type/#{output.type.code_hash}-#{output.type.hash_type}-#{output.type.args}"
            if !local_cache.read(type_cache_key)
              script_hash = output.type.compute_hash
              unless TypeScript.where(code_hash: output.type.code_hash, hash_type: output.type.hash_type, args: output.type.args).exists?
                types_attributes << script_attributes(output.type, script_hash)
                local_cache.write(type_cache_key, true)
              end
            end
          end
        end
      end

      [locks_attributes.to_a.compact, types_attributes.to_a.compact]
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
input_capacities, tags, udt_address_ids, dao_address_ids, contained_udt_ids, contained_addr_ids, prev_outputs, addrs_changes, token_transfer_ckb_tx_ids
    )
      tx_index = 0

      inputs.each do |tx_index, items|
        input_capacities[tx_index] = 0 if tx_index != 0
        items.each_with_index do |item, index|
          # attributes[0] is cell_inputs_attributes
          # attributes[1] is prev_cell_outputs_attributes
          # attributes[2] is previous_cell_output capacity
          # attributes[3] is previous_cell_output type_hash
          # attributes[4] is previous_cell address_id
          # attributes[5] is previous_cell data
          attributes = cell_input_attributes(item, ckb_txs[tx_index]["id"],
                                             local_block_id, prev_outputs, index)
          cell_inputs_attributes << attributes[:cell_input]
          previous_output = attributes[:previous_output]
          if previous_output.present?
            address_id = attributes[:address_id]
            capacity = attributes[:capacity]
            type_hash = attributes[:type_hash]
            data = attributes[:data]
            change_rec = addrs_changes[address_id]
            # change_rec.with_defaults!

            change_rec[:balance_diff] ||= 0
            change_rec[:balance_diff]  -= capacity
            change_rec[:balance_occupied_diff] ||= 0
            change_rec[:balance_occupied_diff] -= capacity if occupied?(
              type_hash, data
            )
            change_rec[:cells_diff] ||= 0
            change_rec[:cells_diff] -= 1
            change_rec[:ckb_txs] ||= Set.new
            change_rec[:ckb_txs] << ckb_txs[tx_index]["tx_hash"]

            prev_cell_outputs_attributes << previous_output
            contained_addr_ids[tx_index] << address_id
            cell_type = previous_output[:cell_type].to_s
            if cell_type.in?(%w(nervos_dao_withdrawing))
              tags[tx_index] << "dao"
              dao_address_ids[tx_index] << address_id
              change_rec[:dao_txs] ||= Set.new
              change_rec[:dao_txs] << ckb_txs[tx_index]["tx_hash"]
            elsif cell_type.in?(%w(m_nft_token nrc_721_token spore_cell did_cell))
              token_transfer_ckb_tx_ids << ckb_txs[tx_index]["id"]
            end

            case previous_output[:cell_type]
            when "udt"
              tags[tx_index] << "udt"
              udt_address_ids[tx_index] << address_id
              contained_udt_ids[tx_index] << Udt.where(type_hash:,
                                                       udt_type: "sudt").pick(:id)
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

    def build_cell_outputs!(
      node_block, outputs, ckb_txs, local_block, cell_outputs_attributes, output_capacities,
tags, udt_address_ids, dao_address_ids, contained_udt_ids, contained_addr_ids, addrs_changes, token_transfer_ckb_tx_ids
    )
      outputs.each do |tx_index, items|
        cell_index = 0
        # tx_index == 0 is cellbase, no need to calculate fee
        if tx_index != 0
          output_capacities[tx_index] = 0
        end
        items.each do |item|
          address = local_cache.read("NodeData/Address/#{item.lock.code_hash}-#{item.lock.hash_type}-#{item.lock.args}")
          address_id = address.id
          cell_data = node_block.transactions[tx_index].outputs_data[cell_index]
          change_rec = addrs_changes[address_id]

          change_rec[:balance_diff] ||= 0
          change_rec[:balance_diff] += item.capacity

          change_rec[:balance_occupied_diff] ||= 0
          change_rec[:balance_occupied_diff] += item.capacity if occupied?(
            item.type&.compute_hash, cell_data
          )

          change_rec[:cells_diff] ||= 0
          change_rec[:cells_diff] += 1

          change_rec[:ckb_txs] ||= Set.new
          change_rec[:ckb_txs] << ckb_txs[tx_index]["tx_hash"]

          contained_addr_ids[tx_index] << address.id
          attr = cell_output_attributes(item, address, ckb_txs[tx_index], local_block, cell_index,
                                        node_block.transactions[tx_index].outputs_data[cell_index])
          cell_outputs_attributes << attr

          if attr[:cell_type].in?(%w(nervos_dao_deposit nervos_dao_withdrawing))
            tags[tx_index] << "dao"
            dao_address_ids[tx_index] << address.id
            change_rec[:dao_txs] ||= Set.new
            change_rec[:dao_txs] << ckb_txs[tx_index]["tx_hash"]
          end

          if attr[:cell_type] == "udt"
            tags[tx_index] << "udt"
            udt_address_ids[tx_index] << address.id
            contained_udt_ids[tx_index] << Udt.where(
              type_hash: item.type.compute_hash, udt_type: "sudt",
            ).pick(:id)
          elsif attr[:cell_type] == "omiga_inscription"
            tags[tx_index] << "omiga_inscription"
            udt_address_ids[tx_index] << address_id
            contained_udt_ids[tx_index] << Udt.where(
              type_hash: item.type.compute_hash, udt_type: "omiga_inscription",
            ).pick(:id)
          elsif attr[:cell_type] == "xudt"
            tags[tx_index] << "xudt"
            udt_address_ids[tx_index] << address_id
            contained_udt_ids[tx_index] << Udt.where(
              type_hash: item.type.compute_hash, udt_type: "xudt",
            ).pick(:id)
          elsif attr[:cell_type] == "xudt_compatible"
            tags[tx_index] << "xudt_compatible"
            udt_address_ids[tx_index] << address_id
            contained_udt_ids[tx_index] << Udt.where(
              type_hash: item.type.compute_hash, udt_type: "xudt_compatible",
            ).pick(:id)
          elsif attr[:cell_type].in?(%w(m_nft_token nrc_721_token spore_cell did_cell))
            token_transfer_ckb_tx_ids << ckb_txs[tx_index]["id"]
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
      udt_amount = udt_amount(cell_type(output.type, output_data), output_data,
                              output.type&.args)
      cell_type = cell_type(output.type, output_data).to_s
      if cell_type == "nrc_721_factory"
        update_nrc_factory_cell_info(output.type,
                                     output_data)
      end
      binary_data = CKB::Utils.hex_to_bin(output_data)
      attrs = {
        ckb_transaction_id: ckb_transaction["id"],
        capacity: output.capacity,
        occupied_capacity: CkbUtils.cal_cell_min_capacity(lock_script, type_script, output.capacity, binary_data),
        address_id: address.id,
        block_id: local_block.id,
        tx_hash: ckb_transaction["tx_hash"],
        cell_index:,
        cell_type:,
        block_timestamp: local_block.timestamp,
        type_hash: output.type&.compute_hash,
        dao: local_block.dao,
        lock_script_id: lock_script.id,
        type_script_id: type_script&.id,
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
        previous_output = CellOutput.find_by tx_hash: input.previous_output.tx_hash,
                                             cell_index: input.previous_output.index

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
            status: "dead",
            consumed_by_id: ckb_transaction_id,
            consumed_block_timestamp: CkbTransaction.find(ckb_transaction_id).block_timestamp,
          },
          capacity: previous_output.capacity,
          type_hash: previous_output.type_hash,
          address_id: previous_output.address_id,
          # data: previous_output.data
        }
      end
    end

    def build_ckb_transactions!(node_block, local_block, inputs, outputs, outputs_data)
      cycles = CkbSync::Api.instance.get_block_cycles node_block.header.hash
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
      pending_txs = CkbTransaction.where("tx_hash IN (#{binary_hashes})").where(tx_status: :pending).pluck(
        :tx_hash, :created_at
      )
      CkbTransaction.where("tx_hash IN (#{binary_hashes})").update_all tx_status: "committed"

      txs = CkbTransaction.upsert_all(ckb_transactions_attributes, unique_by: %i[tx_status tx_hash],
                                                                   returning: %w(id tx_hash block_timestamp created_at))

      if pending_txs.any?
        hash_to_pool_times = pending_txs.to_h
        confirmation_time_attrs =
          txs.select do |tx|
            tx["tx_hash"].tr("\\",
                             "0").in?(hash_to_pool_times.keys)
          end.map do |tx|
            {
              id: tx["id"], tx_status: :committed,
              confirmation_time: (tx["block_timestamp"].to_i / 1000) - hash_to_pool_times[tx["tx_hash"].tr("\\", "0")].to_i
            }
          end
        CkbTransaction.upsert_all(confirmation_time_attrs, update_only: [:confirmation_time],
                                                           unique_by: %i[id tx_status])
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
        HeaderDependency.upsert_all(header_deps_attrs,
                                    unique_by: %i[ckb_transaction_id index])
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
        Witness.upsert_all(witnesses_attrs,
                           unique_by: %i[ckb_transaction_id
                                         index])
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
        bytes: tx.serialized_size_in_block,
        tx_index: tx_index
      }
    end

    def build_uncle_blocks!(node_block, local_block_id)
      node_block.uncles.each do |uncle_block|
        header = uncle_block.header
        epoch_info = CkbUtils.parse_epoch_info(header)
        UncleBlock.create_with(
          compact_target: header.compact_target,
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
      lock = LockScript.find_or_create_by(
        code_hash: lock_script.code_hash,
        hash_type: lock_script.hash_type,
        args: lock_script.args,
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

    def update_address_balance_and_ckb_transactions_count(local_tip_block)
      local_tip_block.contained_addresses.each do |address|
        address.live_cells_count = address.cell_outputs.live.count
        # address.ckb_transactions_count = address.custom_ckb_transactions.count
        address.ckb_transactions_count = AccountBook.where(address_id: address.id).count
        address.dao_transactions_count = AddressDaoTransaction.where(address_id: address.id).count
        address.cal_balance!
        address.save!
      end
    end

    def update_nrc_factory_cell_info(type_script, output_data)
      factory_cell = NrcFactoryCell.find_or_create_by(
        code_hash: type_script.code_hash,
        hash_type: type_script.hash_type,
        args: type_script.args,
      )
      parsed_factory_data = CkbUtils.parse_nrc_721_factory_data(output_data)
      factory_cell.update(
        name: parsed_factory_data.name,
        symbol: parsed_factory_data.symbol,
        base_token_uri: parsed_factory_data.base_token_uri,
        extra_data: parsed_factory_data.extra_data,
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
