namespace :migration do
	desc "Usage: RAILS_ENV=production bundle exec rake migration:generate_tx_display_infos"
	task generate_tx_display_infos: :environment do
		sql =
			<<-SQL
				select id from ckb_transactions 
				except 
				select ckb_transaction_id from tx_display_infos
			SQL
		tx_ids = CkbTransaction.find_by_sql(sql)
		progress_bar = ProgressBar.create({ total: tx_ids.count, format: "%e %B %p%% %c/%C" })
		CkbTransaction.where(id: tx_ids).order(:id).find_in_batches(batch_size: 3000).each do |txs|
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