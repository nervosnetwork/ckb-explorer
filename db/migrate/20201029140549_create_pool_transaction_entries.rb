class CreatePoolTransactionEntries < ActiveRecord::Migration[6.0]
	def change
		create_table :pool_transaction_entries do |t|
			t.jsonb :cell_deps
			t.binary :tx_hash
			t.jsonb :header_deps
			t.jsonb :inputs
			t.jsonb :outputs
			t.jsonb :outputs_data
			t.integer :version
			t.jsonb :witnesses
			t.decimal :transaction_fee, precision: 30, scale: 0
			t.decimal :block_number, precision: 30, scale: 0
			t.decimal :block_timestamp, precision: 30, scale: 0
			t.decimal :cycles, precision: 30, scale: 0
			t.decimal :size, precision: 30, scale: 0
			t.jsonb :display_inputs
			t.jsonb :display_outputs
			t.integer :tx_status, default: 0

			t.timestamps
		end

		add_index :pool_transaction_entries, :tx_hash, unique: true
	end
end
