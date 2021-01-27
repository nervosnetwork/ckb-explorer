module CkbSync
	class NewNodeDataProcessor
		def initialize
			@local_cache = LocalCache.new
		end

		def call
			local_tip_block = Block.recent.first
			tip_block_number = CkbSync::Api.instance.get_tip_block_number
			target_block_number = local_tip_block.present? ? local_tip_block.number + 1 : 0
			return if target_block_number > tip_block_number
			puts "target_block_number: #{target_block_number}"

			target_block = CkbSync::Api.instance.get_block_by_number(target_block_number)
			if !forked?(target_block, local_tip_block)
				process_block(target_block)
			else
				# TODO
			end
		end

		def process_block(node_block)
			ApplicationRecord.transaction do
				# build node data
				local_block = build_block!(node_block)
				build_uncle_blocks!(node_block, local_block.id)
				build_ckb_transactions!(node_block, local_block.id)
				build_cells_and_locks!(node_block, local_block)

				# update explorer data
				build_udts!(local_block)
				consume_previous_cell_outputs(local_block)
				update_ckb_txs_rel_and_fee(local_block)
				update_block_info!(local_block)
				update_addresses_info(local_block)
				update_mining_info(local_block)
				update_table_records_count(local_block)
			end
		end

		private
		attr_accessor :local_cache
		private_constant :LocalCache

		def update_table_records_count(local_block)
			block_counter = TableRecordCount.find_by(table_name: "blocks")
			block_counter.increment!(:count)
			ckb_transaction_counter = TableRecordCount.find_by(table_name: "ckb_transactions")
			normal_transactions = local_block.ckb_transactions.normal
			ckb_transaction_counter.increment!(:count, normal_transactions.count) if normal_transactions.present?
		end

		def update_block_reward_info(local_block)
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
			local_block.contained_addresses.select(:id, :created_at).each do |address|
				address_attributes << { id: address.id, balance: address.cell_outputs.live.sum(:capacity),
				                        ckb_transactions_count: address.custom_ckb_transactions.count,
				                        live_cells_count: address.cell_outputs.live.count,
				                        dao_transactions_count: address.ckb_dao_transactions.count, created_at: address.created_at, updated_at: Time.current }
			end
			Address.upsert_all(address_attributes)
		end

		def update_block_info!(local_block)
			local_block.update!(total_transaction_fee: local_block.ckb_transactions.sum(:transaction_fee),
			                   ckb_transactions_count: local_block.ckb_transactions.count,
			                   live_cell_changes: local_block.ckb_transactions.sum(&:live_cell_changes),
			                   address_ids: local_block.ckb_transactions.pluck(:contained_address_ids).flatten.uniq)
		end

		def build_udts!(local_block)
			local_block.cell_outputs.udt.pluck(:type_hash).each do |type_hash|
				Udt.find_or_create_by!(type_hash: type_hash, udt_type: "sudt")
			end
		end

		def update_ckb_txs_rel_and_fee(local_block)
			ckb_transactions_attributes = []
			local_block.ckb_transactions.each do |tx|
				tags = Set.new
				dao_address_ids = []
				udt_address_ids = []
				contained_udt_ids = []
				input_address_ids = tx.inputs.pluck(:address_id)
				output_address_ids = tx.outputs.pluck(:address_id)
				contained_address_ids = (input_address_ids.uniq! || input_address_ids) + (output_address_ids.uniq! || output_address_ids)
				build_ckb_tx_dao_relation(dao_address_ids, tags, tx)
				build_ckb_tx_udt_relation(udt_address_ids, contained_udt_ids, tags, tx)
				input_capacities = tx.inputs.sum(:capacity)
				output_capacities = tx.outputs.sum(:capacity)
				ckb_transactions_attributes << { id: tx.id, dao_address_ids: (dao_address_ids.uniq! || dao_address_ids),
				                                 udt_address_ids: (udt_address_ids.uniq! || udt_address_ids), contained_udt_ids: (contained_udt_ids.uniq! || contained_udt_ids),
				                                 contained_address_ids: (contained_address_ids.uniq! || contained_address_ids), tags: tags.to_a,
				                                 capacity_involved: input_capacities, transaction_fee: CkbUtils.ckb_transaction_fee(ckb_transaction, input_capacities, output_capacities),
				                                 created_at: tx.created_at, updated_at: Time.current }
			end

			CkbTransaction.upsert_all(ckb_transactions_attributes)
		end

		def build_ckb_tx_udt_relation(udt_address_ids, contained_udt_ids, tags, tx)
			input_udt_address_ids = tx.inputs.udt.pluck(:address_id)
			input_udt_type_hashes = tx.inputs.udt.pluck(:type_hash)
			if input_udt_address_ids.present?
				tags << "udt"
				contained_udt_ids.concat(Udt.where(type_hash: input_udt_type_hashes, udt_type: "sudt").pluck(:id))
				udt_address_ids.concat(input_udt_address_ids)
			end
			output_udt_address_ids = tx.outputs.udt.pluck(:address_id)
			output_udt_type_hashes = tx.outputs.udt.pluck(:type_hash)
			if output_udt_address_ids.present?
				tags << "udt"
				contained_udt_ids.concat(Udt.where(type_hash: output_udt_type_hashes, udt_type: "sudt").pluck(:id))
				udt_address_ids.concat(output_udt_address_ids)
			end
		end

		def build_ckb_tx_dao_relation(dao_address_ids, tags, tx)
			input_dao_address_ids = tx.inputs.nervos_dao_withdrawing.pluck(:address_id)
			if input_dao_address_ids.present?
				tags << "dao"
				dao_address_ids.concat(input_dao_address_ids)
			end
			output_dao_address_ids = tx.outputs.where(cell_type: %w(nervos_dao_deposit nervos_dao_withdrawing)).pluck(:address_id)
			if output_dao_address_ids.present?
				tags << "dao"
				dao_address_ids.concat(output_dao_address_ids)
			end
		end

		def consume_previous_cell_outputs(local_block)
			local_block.cell_inputs.where(from_cell_base: false, previous_cell_output_id: nil).select(:id).find_in_batches(batch_size: 3500) do |cell_inputs|
				cell_inputs_attributes = []
				cell_outputs_attributes = []
				cell_inputs.each do |cell_input|
					previous_cell_output = cell_input.previous_cell_output
					cell_inputs_attributes << { id: cell_input.id, previous_cell_output_id: previous_cell_output.id, created_at: cell_input.created_at, updated_at: Time.current }
					cell_outputs_attributes << { id: previous_cell_output.id, consumed_by_id: cell_input.ckb_transaction_id, consumed_block_timestamp: local_block.timestamp, status: "dead", created_at: previous_cell_output.created_at, updated_at: Time.current }
				end
				CellInput.update_all(cell_inputs_attributes) if cell_inputs_attributes.present?
				CellOutput.update_all(cell_outputs_attributes) if cell_outputs_attributes.present?
			end
		end

		def build_cells_and_locks!(node_block, local_block)
			node_block.transactions do |tx|
				ckb_transaction = CkbTransaction.where(tx_hash: tx.hash).select(:id, :tx_hash, :block_timestamp).take!
				build_cell_inputs(tx, ckb_transaction.id, local_block.id)
				build_scripts(tx.outputs)
				build_cell_outputs(tx, ckb_transaction, local_block)
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

				unless TypeScript.where(code_hash: output.lock.code_hash, hash_type: output.lock.hash_type, args: output.lock.args).exists?
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
				lock_hash: script.compute_hash
			}
		end

		def build_cell_inputs(tx, ckb_transaction_id, local_block_id)
			cell_inputs_attributes = []
			tx.inputs.each do |input|
				cell_inputs_attributes << cell_input_attributes(input, ckb_transaction_id, local_block_id)
			end
			CellInput.insert_all!(cell_inputs_attributes)
		end

		def build_cell_outputs(tx, ckb_transaction, local_block)
			cell_outputs_attributes = []
			tx.outputs.each_with_index do |output, cell_index|
				address =
					local_cache.fetch("NodeData/Address/#{output.lock.code_hash}-#{output.lock.hash_type}-#{output.lock.args}") do
						Address.find_or_create_address(output.lock, ckb_transaction.block_timestamp)
					end
				cell_outputs_attributes << cell_output_attributes(output, address, ckb_transaction, local_block, cell_index, tx.outputs_data[cell_index])
			end
			CellOutput.insert_all!(cell_outputs_attributes)
		end

		def cell_output_attributes(output, address, ckb_transaction, local_block, cell_index, output_data)
			lock_script =
				local_cache.fetch("NodeData/LockScript/#{output.lock.code_hash}-#{output.lock.hash_type}-#{output.lock.args}") do
					LockScript.where(code_hash: output.lock.code_hash, hash_type: output.lock.hash_type, args: output.lock.args).select(:id).take!
				end
			type_script =
				local_cache.fetch("NodeData/TypeScript/#{output.type.code_hash}-#{output.type.hash_type}-#{output.type.args}") do
					TypeScript.where(code_hash: output.type.code_hash, hash_type: output.type.hash_type, args: output.type.args).select(:id).take!
				end

			{
				ckb_transaction_id: ckb_transaction.id,
				capacity: output.capacity,
				data: output_data,
				data_size: CKB::Utils.hex_to_bin(output_data).bytesize,
				occupied_capacity: CkbUtils.calculate_cell_min_capacity(output, output_data),
				address_id: address.id,
				block_id: local_block.id,
				tx_hash: ckb_transaction.tx_hash,
				cell_index: cell_index,
				generated_by_id: ckb_transaction.id,
				cell_type: cell_type(output.type, output_data),
				block_timestamp: ckb_transaction.block_timestamp,
				type_hash: output.type&.compute_hash,
				dao: local_block.dao,
				lock_script_id: lock_script.id,
				type_script_id: type_script&.id
			}
		end

		def cell_input_attributes(input, ckb_transaction_id, local_block_id)
			{
				ckb_transaction_id: ckb_transaction_id,
				previous_output: input.previous_output,
				since: input.since,
				block: local_block_id,
				from_cell_base: from_cell_base?(input)
			}
		end

		def build_ckb_transactions!(node_block, local_block)
			ckb_transactions_attributes = []
			node_block.transactions.each_with_index do |tx, tx_index|
				ckb_transactions_attributes << ckb_transaction_attributes(local_block, tx, tx_index)
			end
			CkbTransaction.insert_all!(ckb_transactions_attributes)
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
				live_cell_changes: live_cell_changes(tx, tx_index)
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
				block_size: node_block.serialized_size_without_uncle_proposals
			)
		end

		class LocalCache
			attr_accessor :cache

			def initialize
				@cache = Set.new
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

