class CreateFiberStatistics < ActiveRecord::Migration[7.0]
  def change
    create_table :fiber_statistics do |t|
      t.integer :total_nodes
      t.integer :total_channels
      t.bigint :total_liquidity
      t.bigint :mean_value_locked
      t.integer :mean_fee_rate
      t.bigint :medium_value_locked
      t.integer :medium_fee_rate
      t.integer :created_at_unixtimestamp

      t.timestamps
    end

    add_index :fiber_statistics, :created_at_unixtimestamp, unique: true
  end
end
