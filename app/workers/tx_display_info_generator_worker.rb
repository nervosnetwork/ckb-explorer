class TxDisplayInfoGeneratorWorker
	include Sidekiq::Worker

	def perform(tx_ids)
		value =
			tx_ids.map do |tx_id|
				tx = CkbTransaction.find(tx_id)
				{ ckb_transaction_id: tx_id, inputs: tx.display_inputs, outputs: tx.display_outputs, created_at: Time.current, updated_at: Time.current }
			end

		if value.present?
			TxDisplayInfo.upsert_all(value)
		end
	end
end