class CreateUdtHourlyStatistics < ActiveRecord::Migration[7.0]
  def change
    create_table :udt_hourly_statistics do |t|
      t.bigint :udt_id, null: false
      t.integer :ckb_transactions_count, default: 0
      t.decimal :amount, precision: 40, default: 0.0
      t.integer :holders_count, default: 0
      t.integer :created_at_unixtimestamp
      t.timestamps
    end

    add_index :udt_hourly_statistics, %i[udt_id created_at_unixtimestamp], name: "index_on_udt_id_and_unixtimestamp", unique: true
  end
end
