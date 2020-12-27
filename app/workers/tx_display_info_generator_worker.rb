class TxDisplayInfoGeneratorWorker
	include Sidekiq::Worker

	def perform(tx_ids)
		value =
			tx_ids.map do |tx_id|
				tx = CkbTransaction.find(id: tx_id)
				if tx.present?
					{ ckb_transaction_id: tx_id, inputs: tx.display_inputs, outputs: tx.display_outputs, created_at: Time.current, updated_at: Time.current }
				end
			end

		if value.compact.present?
			TxDisplayInfo.upsert_all(value)
		end
	end
end