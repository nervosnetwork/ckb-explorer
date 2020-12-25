namespace :migration do
	desc "Usage: RAILS_ENV=production bundle exec rake 'migration:generate_tx_display_infos[0]'"
	task :generate_tx_display_infos, [:tx_id] => :environment do |_, args|
		progress_bar = ProgressBar.create({ total: CkbTransaction.count, format: "%e %B %p%% %c/%C" })
		if args[:tx_id].present?
			tx_id = args[:tx_id].to_i
		else
			tx_id = 0
		end
		puts "tx_id: #{tx_id}"
		CkbTransaction.where("id > ?", tx_id).order(:id).find_in_batches(batch_size: 3000).each do |txs|
			value =
				txs.map do |tx|
					progress_bar.increment
					{ ckb_transaction_id: tx.id, inputs: tx.display_inputs, outputs: tx.display_outputs, created_at: Time.current, updated_at: Time.current }
				end
			if value.present?
				TxDisplayInfo.upsert_all(value)
			end
		end
	end
end