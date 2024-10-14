class CreateFiberGraphInfos < ActiveRecord::Migration[7.0]
  def change
    create_table :fiber_graph_nodes do |t|
      t.string :alias
      t.string :node_id
      t.string :addresses, array: true, default: [], using: "(string_to_array(addresses, ','))"
      t.bigint :timestamp
      t.string :chain_hash
      t.decimal :auto_accept_min_ckb_funding_amount, precision: 30

      t.timestamps
    end

    create_table :fiber_graph_channels do |t|
      t.string :channel_outpoint
      t.bigint :funding_tx_block_number
      t.integer :funding_tx_index
      t.string :node1
      t.string :node2
      t.bigint :last_updated_timestamp
      t.bigint :created_timestamp
      t.decimal :node1_to_node2_fee_rate, precision: 30, default: 0.0
      t.decimal :node2_to_node1_fee_rate, precision: 30, default: 0.0
      t.decimal :capacity, precision: 64, scale: 2, default: 0.0
      t.string :chain_hash

      t.timestamps
    end

    add_index :fiber_graph_nodes, :node_id, unique: true
    add_index :fiber_graph_channels, :channel_outpoint, unique: true
  end
end
