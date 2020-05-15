class CreateTransactionPropagationDelays < ActiveRecord::Migration[6.0]
  def change
    create_table :transaction_propagation_delays do |t|
      t.string :tx_hash
      t.integer :created_at_unixtimestamp
      t.jsonb :durations

      t.timestamps
    end

    add_index :transaction_propagation_delays, :created_at_unixtimestamp, name: "index_tx_propagation_timestamp"
  end
end
