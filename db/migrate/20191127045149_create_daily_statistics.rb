class CreateDailyStatistics < ActiveRecord::Migration[6.0]
  def change
    create_table :daily_statistics do |t|
      t.integer :transactions_count, default: 0
      t.integer :addresses_count, default: 0
      t.decimal :total_dao_deposit, precision: 30, default: 0
      t.decimal :block_timestamp, precision: 30
      t.integer :created_at_unixtimestamp

      t.timestamps
    end
  end
end
