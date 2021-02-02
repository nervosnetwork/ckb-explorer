require 'pry'
module CkbSync
	class NewNodeDataProcessor
		def initialize
			@local_cache = LocalCache.new
		end

		def call
			target_block_number = 0
			result = Benchmark.realtime do
			local_tip_block = Block.recent.first
			tip_block_number = CkbSync::Api.instance.get_tip_block_number
			target_block_number = local_tip_block.present? ? local_tip_block.number + 1 : 0
			return if target_block_number > tip_block_number
			target_block = CkbSync::Api.instance.get_block_by_number(target_block_number)
			if !forked?(target_block, local_tip_block)
				process_block(target_block)
			else
				# TODO
			end
			end
			puts "target_block_number: #{target_block_number}: %5.3f" % result
		end

		def process_block(node_block)
			local_block = nil
			ApplicationRecord.transaction do
				# build node data
				# result = Benchmark.realtime do
				local_block = build_block!(node_block)
				# end
				# puts "build_block!: %5.3f" % result
				# puts "block_id: #{local_block.id}"
				# result = Benchmark.realtime do
					build_uncle_blocks!(node_block, local_block.id)
				# end
				# puts "build_uncle_blocks!: %5.3f" % result
				# ckb_txs = nil
				# result = Benchmark.realtime do
					ckb_txs = build_ckb_transactions!(node_block, local_block)
				# end
				ckb_txs.each { |cbk_tx| cbk_tx["tx_hash"][0] = "0" }

				# puts "build_ckb_transactions!: %5.3f" % result

				# result = Benchmark.realtime do
					build_cells_and_locks!(node_block, local_block, ckb_txs)
				# end
				# puts "build_cells_and_locks!: %5.3f" % result

				# update explorer data
				# result = Benchmark.realtime do
					build_udts!(local_block)
				# end
				# puts "build_udts!: %5.3f" % result
				# result = Benchmark.realtime do
					consume_previous_cell_outputs(local_block)
				# end
				# puts "consume_previous_cell_outputs: %5.3f" % result

				# result = Benchmark.realtime do
					update_ckb_txs_rel_and_fee(ckb_txs)
				# end
				# puts "update_ckb_txs_rel_and_fee: %5.3f" % result

				# result = Benchmark.realtime do
					update_block_info!(local_block)
				# end
				# puts "update_block_info!: %5.3f" % result

				# result = Benchmark.realtime do
					update_block_reward_info!(local_block)
				# end
				# puts "update_block_reward_info!: %5.3f" % result

				# result = Benchmark.realtime do
					update_addresses_info(local_block)
				# end
				# puts "update_addresses_info: %5.3f" % result
				# result = Benchmark.realtime do
					update_mining_info(local_block)
				# end
				# puts "update_mining_info: %5.3f" % result
				# result = Benchmark.realtime do
					update_table_records_count(local_block)
				# end
				# puts "update_table_records_count: %5.3f" % result

				# result = Benchmark.realtime do
					update_or_create_udt_accounts!(local_block)
				# end
				# puts "update_or_create_udt_accounts!: %5.3f" % result

				# result = Benchmark.realtime do
					update_pool_tx_status(local_block)
				# end
				# puts "update_pool_tx_status: %5.3f" % result
				# maybe can be changed to asynchronous update
				# result = Benchmark.realtime do
					update_udt_info(local_block)
				# end
				# puts "update_udt_info: %5.3f" % result
				# result = Benchmark.realtime do
					process_dao_events!(local_block)
				# end
				# puts "process_dao_events!: %5.3f" % result
			end

			# result = Benchmark.realtime do
				cache_address_txs(local_block)
			# end
			# puts "cache_address_txs: %5.3f" % result

			# result = Benchmark.realtime do
				generate_tx_display_info(local_block)
			# end
			# puts "generate_tx_display_info: %5.3f" % result

			# result = Benchmark.realtime do
				remove_tx_display_infos(local_block)
			# end
			# puts "remove_tx_display_infos: %5.3f" % result
			# result = Benchmark.realtime do
				flush_inputs_outputs_caches(local_block)
			# end
			# puts "flush_inputs_outputs_caches: %5.3f" % result

			local_block
		end

		private
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
				new_dao_events_attributes << { block_id: local_block.id, ckb_transaction_id: ckb_transaction_id, address_id: address_id, event_type: "new_dao_depositor",
				                               value: 1, status: "processed", contract_id: dao_contract.id, block_timestamp: block.timestamp, created_at: Time.current,
				                               updated_at: Time.current }
			end

			if new_dao_events_attributes.present?
				DaoEvent.insert_all!(new_dao_events_attributes)
				dao_contract.update!(depositors_count: dao_contract.depositors_count - new_dao_events_attributes.size)
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
					previous_cell_output = CellOutput.where(id: dao_input.previous_cell_output_id).select(:address_id, :generated_by_id, :address_id, :dao, :cell_index, :capacity).take!
					address = previous_cell_output.address
					interest = CkbUtils.dao_interest(previous_cell_output)
					if addrs_withdraw_info.key?(address.id)
						addrs_withdraw_info[address.id][:dao_deposit] -= previous_cell_output.capacity
						addrs_withdraw_info[address.id][:interest] += interest
					else
						addrs_withdraw_info[address.id] = { dao_deposit: address.dao_deposit - previous_cell_output.capacity, interest: address.interest, is_depositor: address.is_depositor, created_at: address.created_at }
					end
					dao_events_attributes << { ckb_transaction_id: dao_input.ckb_transaction_id, block_id: local_block.id, block_timestamp: local_block.timestamp, address_id: previous_cell_output.address_id, event_type: "withdraw_from_dao", value: previous_cell_output.capacity, status: "processed", contract_id: dao_contract.id, created_at: Time.current,
					                           updated_at: Time.current }
					dao_events_attributes << { ckb_transaction_id: dao_input.ckb_transaction_id, block_id: local_block.id, block_timestamp: local_block.timestamp, address_id: previous_cell_output.address_id, event_type: "issue_interest", value: interest, status: "processed", contract_id: dao_contract.id, created_at: Time.current,
					                           updated_at: Time.current }
					address_dao_deposit = Address.where(id: previous_cell_output.address_id).pick(:dao_deposit)
					if (address_dao_deposit - previous_cell_output.capacity).zero?
						take_away_all_deposit_count += 1
						addrs_withdraw_info[address.id][:is_depositor] = false
						dao_events_attributes << { ckb_transaction_id: dao_input.ckb_transaction_id, block_id: local_block.id, block_timestamp: local_block.timestamp, address_id: previous_cell_output.address_id, event_type: "take_away_all_deposit", value: 1, status: "processed", contract_id: dao_contract.id, created_at: Time.current,
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
			local_block.cell_outputs.nervos_dao_deposit.select(:address_id, :capacity, :ckb_transaction_id).find_in_batches do |dao_outputs|
				deposit_dao_events_attributes = []
				dao_outputs.each do |dao_output|
					address = dao_output.address
					if addresses_deposit_info.key?(address_id)
						addresses_deposit_info[address.id][:dao_deposit] += dao_output.capacity
					else
						addresses_deposit_info[address.id] = { dao_deposit: address.dao_deposit + dao_output.capacity, interest: address.interest, is_depositor: address.is_depositor, created_at: address.created_at }
					end
					if address.dao_deposit.zero? && !new_dao_depositors.key?(address.id)
						new_dao_depositors[address.id] = dao_output.ckb_transaction_id
					end
					deposit_amount += dao_output.capacity
					deposit_transaction_ids << dao_output.ckb_transaction_id
					deposit_dao_events_attributes << { ckb_transaction_id: dao_output.ckb_transaction_id, block_id: local_block.id, address_id: address.id, event_type: "deposit_to_dao",
					                                   value: dao_output.capacity, status: "processed", contract_id: dao_contract.id, block_timestamp: block.timestamp,created_at: Time.current,
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
				addresses_deposit_attributes << { id: address_id, dao_deposit: address_info[:dao_deposit], created_at: address_info[:created_at], updated_at: Time.current }
			end
			Address.upsert_all(addresses_deposit_attributes) if addresses_deposit_attributes.present?
		end

		def update_pool_tx_status(local_block)
			PoolTransactionEntry.pool_transaction_pending.where(tx_hash: local_block.ckb_transactions.pluck(:tx_hash)).update_all(tx_status: "committed")
		end

		def update_udt_info(local_block)
			type_hashes = []
			local_block.cell_outputs.udt.select(:type_hash).find_each do |udt_output|
				type_hashes << udt_output.type_hash
			end
			return if type_hashes.blank?

			amount_info = UdtAccount.where(type_hash: type_hashes).group(:type_hash).sum(:amount)
			addresses_count_info = UdtAccount.where(type_hash: type_hashes).group(:type_hash).count(:address_id)
			udts_attributes = []
			type_hashes.each do |type_hash|
				udts_attributes << { type_hash: type_hash, total_amount: amount_info[type_hash], addresses_count: addresses_count_info[type_hash] }
			end

			Udt.upsert_all(udts_attributes, unique_by: :type_hash) if udts_attributes.present?
		end

		def update_or_create_udt_accounts!(local_block)
			new_udt_accounts_attributes = []
			udt_accounts_attributes = []
			local_block.cell_outputs.udt.select(:address_id, :type_hash).find_each do |udt_output|
				address = Address.find(udt_output.address_id)
				udt_account = address.udt_accounts.where(type_hash: udt_output.type_hash).select(:id, :created_at)
				if udt_account.present?
					udt_accounts_attributes << { id: udt_account.id, amount: amount, created_at: udt.created_at, updated_at: Time.current }
				else
					udt = Udt.where(type_hash: type_hash, udt_type: "sudt").select(:id, :udt_type, :full_name, :symbol, :decimal, :published, :code_hash, :type_hash).take!
					new_udt_accounts_attributes << { udt_type: udt.udt_type, full_name: udt.full_name, symbol: udt.symbol, decimal: udt.decimal, published: udt.published, code_hash: udt.code_hash, type_hash: udt.type_hash, amount: amount, udt_id: udt.id, created_at: Time.current,
					                                 updated_at: Time.current }
				end
			end

			UdtAccount.insert_all!(new_udt_accounts_attributes) if new_udt_accounts_attributes.present?
			UdtAccount.upsert_all(udt_accounts_attributes) if udt_accounts_attributes.present?
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

		def update_addresses_info(local_block)
			address_attributes = []
			local_block.contained_addresses.select(:id, :created_at).find_each do |address|
				address_attributes << { id: address.id, balance: address.cell_outputs.live.sum(:capacity),
				                        ckb_transactions_count: address.custom_ckb_transactions.count,
				                        live_cells_count: address.cell_outputs.live.count,
				                        dao_transactions_count: address.ckb_dao_transactions.count, created_at: address.created_at, updated_at: Time.current }
			end
			Address.upsert_all(address_attributes) if address_attributes.present?
		end

		def update_block_info!(local_block)
			local_block.update!(total_transaction_fee: local_block.ckb_transactions.sum(:transaction_fee),
			                   ckb_transactions_count: local_block.ckb_transactions.count,
			                   live_cell_changes: local_block.ckb_transactions.sum(&:live_cell_changes),
			                   address_ids: local_block.ckb_transactions.pluck(:contained_address_ids).flatten.uniq)
		end

		def build_udts!(local_block)
			udts_attributes = []
			local_block.cell_outputs.udt.select(:type_hash).find_each do |output|
				unless Udt.where(type_hash: output.type_hash).exists?
					type_script = output.type_script
					issuer_address = Address.where(lock_hash: type_script.args).pick(:address_hash)
					udts_attributes << { type_hash: output.type_hash, udt_type: "sudt", issuer_address: issuer_address,
					                     block_timestamp: local_block.timestamp, args: type_script.args,
					                     code_hash: type_script.code_hash, hash_type: type_script.hash_type, created_at: Time.current,
					                     updated_at: Time.current }
				end
			end

			Udt.insert_all!(udts_attributes) if udts_attributes.present?
		end

		def update_ckb_txs_rel_and_fee(ckb_txs)
			ckb_transactions_attributes = []
				Parallel.map(ckb_txs.select { |ckb_tx| ckb_tx["is_cellbase"] == false }, finish: -> (_, _, result) { ckb_transactions_attributes << result }) do |tx|
			# ckb_transactions_attributes = ckb_txs.select { |ckb_tx| ckb_tx["is_cellbase"] == false }.map do |tx|
					tags = Set.new
					dao_address_ids = []
					udt_address_ids = []
					contained_udt_ids = []
					input_address_ids = CellOutput.where(consumed_by_id: tx["id"]).pluck(:address_id) #tx.inputs.pluck(:address_id)
					output_address_ids = CellOutput.where(generated_by: tx["id"]).pluck(:address_id) #tx.outputs.pluck(:address_id)
					contained_address_ids = (input_address_ids.uniq! || input_address_ids) + (output_address_ids.uniq! || output_address_ids)
					build_ckb_tx_dao_relation(dao_address_ids, tags, tx)
					build_ckb_tx_udt_relation(udt_address_ids, contained_udt_ids, tags, tx)
					input_capacities = CellOutput.where(consumed_by_id: tx["id"]).sum(:capacity)
					output_capacities = CellOutput.where(generated_by: tx["id"]).sum(:capacity)
					{ id: tx["id"], dao_address_ids: (dao_address_ids.uniq! || dao_address_ids),
					                                 udt_address_ids: (udt_address_ids.uniq! || udt_address_ids), contained_udt_ids: (contained_udt_ids.uniq! || contained_udt_ids),
					                                 contained_address_ids: (contained_address_ids.uniq! || contained_address_ids), tags: tags.to_a,
					                                 capacity_involved: input_capacities, transaction_fee: CkbUtils.ckb_transaction_fee(tx, input_capacities, output_capacities),
					                                 created_at: tx["created_at"], updated_at: Time.current}
				end
				CkbTransaction.upsert_all(ckb_transactions_attributes) if ckb_transactions_attributes.present?
		end

		def build_ckb_tx_udt_relation(udt_address_ids, contained_udt_ids, tags, tx)
			input_udt_address_ids = CellOutput.where(consumed_by_id: tx["id"]).udt.pluck(:address_id)
			input_udt_type_hashes = CellOutput.where(consumed_by_id: tx["id"]).udt.pluck(:type_hash)
			if input_udt_address_ids.present?
				tags << "udt"
				contained_udt_ids.concat(Udt.where(type_hash: input_udt_type_hashes, udt_type: "sudt").pluck(:id))
				udt_address_ids.concat(input_udt_address_ids)
			end
			output_udt_address_ids = CellOutput.where(generated_by: tx["id"]).udt.pluck(:address_id)
			output_udt_type_hashes = CellOutput.where(generated_by: tx["id"]).udt.pluck(:type_hash)
			if output_udt_address_ids.present?
				tags << "udt"
				contained_udt_ids.concat(Udt.where(type_hash: output_udt_type_hashes, udt_type: "sudt").pluck(:id))
				udt_address_ids.concat(output_udt_address_ids)
			end
		end

		def build_ckb_tx_dao_relation(dao_address_ids, tags, tx)
			input_dao_address_ids = CellOutput.where(consumed_by_id: tx["id"]).nervos_dao_withdrawing.pluck(:address_id)
			if input_dao_address_ids.present?
				tags << "dao"
				dao_address_ids.concat(input_dao_address_ids)
			end
			output_dao_address_ids = CellOutput.where(generated_by: tx["id"]).where(cell_type: %w(nervos_dao_deposit nervos_dao_withdrawing)).pluck(:address_id)
			if output_dao_address_ids.present?
				tags << "dao"
				dao_address_ids.concat(output_dao_address_ids)
			end
		end

		def consume_previous_cell_outputs(local_block)
			local_block.cell_inputs.where(from_cell_base: false).select(:id, :cell_type, :previous_output, :created_at, :ckb_transaction_id).find_in_batches(batch_size: 3500) do |cell_inputs|
				cell_inputs_attributes = []
				cell_outputs_attributes = []
				finish = lambda do |_, _, result|
					cell_inputs_attributes << result[0]
					cell_outputs_attributes << result[1]
				end
				Parallel.map(cell_inputs, finish: finish) do |cell_input|
				# cell_inputs.each do |cell_input|
					previous_cell_output = cell_input.previous_cell_output
					# cell_inputs_attributes << { id: cell_input.id, previous_cell_output_id: previous_cell_output.id, cell_type: previous_cell_output.cell_type, created_at: cell_input.created_at, updated_at: Time.current }
					# cell_outputs_attributes << { id: previous_cell_output.id, consumed_by_id: cell_input.ckb_transaction_id, consumed_block_timestamp: local_block.timestamp, status: "dead", created_at: previous_cell_output.created_at, updated_at: Time.current }
					[{ id: cell_input.id, previous_cell_output_id: previous_cell_output.id, cell_type: previous_cell_output.cell_type, created_at: cell_input.created_at, updated_at: Time.current },
					 { id: previous_cell_output.id, consumed_by_id: cell_input.ckb_transaction_id, consumed_block_timestamp: local_block.timestamp, status: "dead", created_at: previous_cell_output.created_at, updated_at: Time.current }]
				end

				Parallel.each([0]) do
					CellInput.upsert_all(cell_inputs_attributes) if cell_inputs_attributes.present?
					CellOutput.upsert_all(cell_outputs_attributes) if cell_outputs_attributes.present?
				end
				#
				# CellInput.upsert_all(cell_inputs_attributes) if cell_inputs_attributes.present?
				# CellOutput.upsert_all(cell_outputs_attributes) if cell_outputs_attributes.present?
				end
		end

		def build_cells_and_locks!(node_block, local_block, ckb_txs)
			Parallel.each(node_block.transactions) do |tx|
			# node_block.transactions do |tx|
				ckb_tx = ckb_txs.select { |ckb_tx| ckb_tx["tx_hash"] == tx.hash }.first
				build_cell_inputs(tx, ckb_tx["id"], local_block.id)
				build_scripts(tx.outputs)
				build_cell_outputs!(tx, ckb_tx, local_block)
			end
		end

		def build_scripts(outputs)
			lock_scripts_attributes = []
			type_scripts_attributes = []
			outputs.each do |output|
				unless LockScript.where(code_hash: output.lock.code_hash, hash_type: output.lock.hash_type, args: output.lock.args).exists?
					lock_scripts_attributes << script_attributes(output.lock)
				end
				next if output.type.blank?

				unless TypeScript.where(code_hash: output.type.code_hash, hash_type: output.type.hash_type, args: output.type.args).exists?
					type_scripts_attributes << script_attributes(output.type)
				end
			end
			LockScript.insert_all!(lock_scripts_attributes) if lock_scripts_attributes.present?
			TypeScript.insert_all!(type_scripts_attributes) if type_scripts_attributes.present?
		end

		def script_attributes(script)
			{
				args: script.args,
				code_hash: script.code_hash,
				hash_type: script.hash_type,
				lock_hash: script.compute_hash,
				created_at: Time.current,
				updated_at: Time.current
			}
		end

		def build_cell_inputs(tx, ckb_transaction_id, local_block_id)
			cell_inputs_attributes = []
			tx.inputs.each do |input|
				cell_inputs_attributes << cell_input_attributes(input, ckb_transaction_id, local_block_id)
			end
			CellInput.insert_all!(cell_inputs_attributes)
		end

		def build_cell_outputs!(tx, ckb_transaction, local_block)
			cell_outputs_attributes = []
			tx.outputs.each_with_index do |output, cell_index|
				address =
					local_cache.fetch("NodeData/Address/#{output.lock.code_hash}-#{output.lock.hash_type}-#{output.lock.args}") do
						Address.find_or_create_address(output.lock, local_block.timestamp)
					end
				cell_outputs_attributes << cell_output_attributes(output, address, ckb_transaction, local_block, cell_index, tx.outputs_data[cell_index])
			end
			CellOutput.insert_all!(cell_outputs_attributes) if cell_outputs_attributes.present?
		end

		def cell_output_attributes(output, address, ckb_transaction, local_block, cell_index, output_data)
			lock_script =
				local_cache.fetch("NodeData/LockScript/#{output.lock.code_hash}-#{output.lock.hash_type}-#{output.lock.args}") do
					LockScript.where(code_hash: output.lock.code_hash, hash_type: output.lock.hash_type, args: output.lock.args).select(:id).take!
				end
			type_script =
				if output.type.present?
					local_cache.fetch("NodeData/TypeScript/#{output.type.code_hash}-#{output.type.hash_type}-#{output.type.args}") do
						TypeScript.where(code_hash: output.type.code_hash, hash_type: output.type.hash_type, args: output.type.args).select(:id).take!
					end
				end

			{
				ckb_transaction_id: ckb_transaction["id"],
				capacity: output.capacity,
				data: output_data,
				data_size: CKB::Utils.hex_to_bin(output_data).bytesize,
				occupied_capacity: CkbUtils.calculate_cell_min_capacity(output, output_data),
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
				created_at: Time.current,
				updated_at: Time.current
			}
		end

		def cell_input_attributes(input, ckb_transaction_id, local_block_id)
			{
				ckb_transaction_id: ckb_transaction_id,
				previous_output: input.previous_output,
				since: input.since,
				block_id: local_block_id,
				from_cell_base: from_cell_base?(input),
				created_at: Time.current,
				updated_at: Time.current
			}
		end

		def build_ckb_transactions!(node_block, local_block)
			ckb_transactions_attributes = []
			node_block.transactions.each_with_index do |tx, tx_index|
				ckb_transactions_attributes << ckb_transaction_attributes(local_block, tx, tx_index)
			end
			CkbTransaction.insert_all!(ckb_transactions_attributes, returning: %w(id tx_hash created_at is_cellbase))
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
					uncles_hash: header.uncles_hash,
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
				block_size: 0#node_block.serialized_size_without_uncle_proposals
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
			address = Address.find_or_create_address(lock_script, block_timestamp)
			LockScript.find_or_create_by(
				args: lock_script.args,
				code_hash: lock_script.code_hash,
				hash_type: lock_script.hash_type,
				address_id: address.id
			)
		end

		def cell_type(type_script, output_data)
			return "normal" unless [ENV["DAO_CODE_HASH"], ENV["DAO_TYPE_HASH"], ENV["SUDT_CELL_TYPE_HASH"], ENV["SUDT1_CELL_TYPE_HASH"]].include?(type_script&.code_hash)

			case type_script&.code_hash
			when ENV["DAO_CODE_HASH"], ENV["DAO_TYPE_HASH"]
				if output_data == CKB::Utils.bin_to_hex("\x00" * 8)
					"nervos_dao_deposit"
				else
					"nervos_dao_withdrawing"
				end
			when ENV["SUDT_CELL_TYPE_HASH"], ENV["SUDT1_CELL_TYPE_HASH"]
				if CKB::Utils.hex_to_bin(output_data).bytesize >= CellOutput::MIN_SUDT_AMOUNT_BYTESIZE
					"udt"
				else
					"normal"
				end
			else
				"normal"
			end
		end

		def forked?(target_block, local_tip_block)
			return false if local_tip_block.blank?

			target_block.header.parent_hash != local_tip_block.block_hash
		end

		class LocalCache
			attr_accessor :cache

			def initialize
				@cache = {}
			end

			def fetch(key)
				return cache[key] if cache[key].present?

				value = yield
				if block_given? && value.present?
					cache[key] = value
				end
			end
		end
	end
	end

