class TxDisplayInfoGeneratorWorker
	include Sidekiq::Worker

	def perform(tx_ids)
		value =
			tx_ids.map do |tx_id|
				tx = CkbTransaction.find_by(id: tx_id)
				if tx.present?
					income = Hash.new
					tx.contained_address_ids.each do |address_id|
						addr = Address.find_by(id: address_id)
						income[addr.address_hash] = tx.income(addr)
					end
					{ ckb_transaction_id: tx_id, inputs: tx.display_inputs, outputs: tx.display_outputs, income: income, created_at: Time.current, updated_at: Time.current }
				end
			end

		if value.compact.present?
			TxDisplayInfo.upsert_all(value)
		end
	end
end