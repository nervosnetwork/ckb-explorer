class ChangeColumnTypesFromDecimalToBigint < ActiveRecord::Migration[7.0]
  def self.up
    # if we don't drop this view, we cannot modify the type of timestamp column in blocks table
    execute "DROP MATERIALIZED VIEW if exists average_block_time_by_hour CASCADE"

    change_table(:addresses, bulk: true) do |t|
      t.change :cell_consumed, :bigint
      t.change :ckb_transactions_count, :bigint
      t.change :block_timestamp, :bigint
      t.change :live_cells_count, :bigint
      t.change :average_deposit_time, :bigint
      t.change :dao_transactions_count, :bigint
    end
    change_table(:blocks, bulk: true) do |t|
      t.change :number, :bigint
      t.change :timestamp, :bigint
      t.change :cell_consumed, :bigint
      t.change :ckb_transactions_count, :bigint
      t.change :epoch, :bigint

      t.change :block_size, :bigint
      t.change :median_timestamp, :bigint
      t.change :block_time, :bigint
    end
    change_table(:block_statistics, bulk: true) do |t|
      t.change :block_number, :bigint
      t.change :epoch_number, :bigint
    end

    change_column :dao_events, :block_id, :bigint

    change_table :epoch_statistics, bulk: true do |t|
      t.change :epoch_number, :bigint
      t.change :epoch_time, :bigint
    end

    change_table :forked_blocks, bulk: true do |t|
      t.change :number, :bigint
      t.change :timestamp, :bigint
      t.change :epoch, :bigint
    end

    change_table :uncle_blocks, bulk: true do |t|
      t.change :number, :bigint
      t.change :timestamp, :bigint
      t.change :epoch, :bigint
    end

    change_table :udts, bulk: true do |t|
      t.change :addresses_count, :bigint
      t.change :block_timestamp, :bigint
      t.change :ckb_transactions_count, :bigint
    end
  end

  def self.down
    change_column :addresses, :cell_consumed, :decimal, precision: 30, scale: 0
    change_column :addresses, :ckb_transactions_count, :decimal, precision: 30, scale: 0
    change_column :addresses, :block_timestamp, :decimal, precision: 30, scale: 0
    change_column :addresses, :live_cells_count, :decimal, precision: 30, scale: 0
    change_column :addresses, :average_deposit_time, :decimal, precision: 30, scale: 0
    change_column :addresses, :dao_transactions_count, :decimal, precision: 30, scale: 0

    change_column :blocks, :number, :decimal, precision: 30, scale: 0
    change_column :blocks, :cell_consumed, :decimal, precision: 30, scale: 0
    change_column :blocks, :ckb_transactions_count, :decimal, precision: 30, scale: 0
    change_column :blocks, :epoch, :decimal, precision: 30, scale: 0
    change_column :blocks, :block_size, :decimal, precision: 30, scale: 0
    change_column :blocks, :median_timestamp, :decimal, precision: 30, scale: 0

    change_column :block_statistics, :block_number, :decimal, precision: 30, scale: 0
    change_column :block_statistics, :epoch_number, :decimal, precision: 30, scale: 0

    change_column :dao_events, :block_id, :decimal, precision: 30, scale: 0

    change_column :epoch_statistics, :epoch_number, :decimal, precision: 30, scale: 0
    change_column :epoch_statistics, :epoch_time, :decimal, precision: 30, scale: 0

    change_column :forked_blocks, :number, :decimal, precision: 30, scale: 0
    change_column :forked_blocks, :timestamp, :decimal, precision: 30, scale: 0
    change_column :forked_blocks, :epoch, :decimal, precision: 30, scale: 0

    change_column :uncle_blocks, :number, :decimal, precision: 30, scale: 0
    change_column :uncle_blocks, :timestamp, :decimal, precision: 30, scale: 0
    change_column :uncle_blocks, :epoch, :decimal, precision: 30, scale: 0

    change_column :udts, :addresses_count, :decimal, precision: 30, scale: 0
    change_column :udts, :block_timestamp, :decimal, precision: 30, scale: 0
    change_column :udts, :ckb_transactions_count, :decimal, precision: 30, scale: 0
  end
end
