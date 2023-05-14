class CreateStatisticInfos < ActiveRecord::Migration[7.0]
  def change
    create_table :statistic_infos do |t|
      t.bigint :transactions_last_24hrs
      t.bigint :transactions_count_per_minute
      t.float :average_block_time
      t.decimal :hash_rate
      t.jsonb :address_balance_ranking
      t.jsonb :miner_ranking
      t.string :blockchain_info
      t.jsonb :last_n_days_transaction_fee_rates

      t.timestamps
    end
  end
end
