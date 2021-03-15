namespace :migration do
	desc "Usage: RAILS_ENV=production bundle exec rake 'migration:generate_tx_display_infos[0]'"
	task :generate_tx_display_infos, [:tx_id] => :environment do |_, args|
		if args[:tx_id].present?
			tx_id = args[:tx_id].to_i
		else
			tx_id = 0
		end
		puts "tx_id: #{tx_id}"
		progress_bar = ProgressBar.create({ total: CkbTransaction.where("id > ?", tx_id).count, format: "%e %B %p%% %c/%C" })
		CkbTransaction.where("id > ?", tx_id).order(:id).find_in_batches(batch_size: 3000).each do |txs|
			value =
				txs.map do |tx|
					progress_bar.increment
					income = Hash.new
					tx.contained_address_ids.each do |address_id|
						addr = Address.find_by(id: address_id)
						income[addr.address_hash] = tx.income(addr)
					end
					{ ckb_transaction_id: tx.id, inputs: tx.display_inputs, outputs: tx.display_outputs, income: income, created_at: Time.current, updated_at: Time.current }
				end
			if value.present?
				TxDisplayInfo.upsert_all(value)
			end
		end
	end
end