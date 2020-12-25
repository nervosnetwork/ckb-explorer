namespace :migration do
	desc "Usage: RAILS_ENV=production bundle exec rake migration:generate_tx_display_infos"
	task generate_tx_display_infos: :environment do
		progress_bar = ProgressBar.create({ total: CkbTransaction.count, format: "%e %B %p%% %c/%C" })
		CkbTransaction.where("id not in (?)", TxDisplayInfo.select(:ckb_transaction_id)).find_in_batches(batch_size: 3000).each do |txs|
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