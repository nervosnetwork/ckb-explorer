class ChangeColumnTypesFromDecimalToBigint < ActiveRecord::Migration[7.0]
  def self.up
    change_column :addresses, :cell_consumed, :bigint
    change_column :addresses, :ckb_transactions_count, :bigint
    change_column :addresses, :block_timestamp, :bigint
    change_column :addresses, :live_cells_count, :bigint
    change_column :addresses, :average_deposit_time, :bigint
    change_column :addresses, :dao_transactions_count, :bigint

    change_column :cell_outputs, :address_id, :bigint
    change_column :cell_outputs, :capacity, :bigint
    change_column :cell_outputs, :generated_by_id, :bigint
    change_column :cell_outputs, :consumed_by_id, :bigint
    change_column :cell_outputs, :block_timestamp, :bigint
    change_column :cell_outputs, :occupied_capacity, :bigint
    change_column :cell_outputs, :consumed_block_timestamp, :bigint

    change_column :blocks, :number, :bigint
    change_column :blocks, :cell_consumed, :bigint
    change_column :blocks, :ckb_transactions_count, :bigint
    change_column :blocks, :epoch, :bigint

    change_column :blocks, :block_size, :bigint
    change_column :blocks, :median_timestamp, :bigint

    change_column :block_statistics, :block_number, :bigint
    change_column :block_statistics, :epoch_number, :bigint

    change_column :dao_events, :block_id, :bigint

    change_column :epoch_statistics, :epoch_number, :bigint
    change_column :epoch_statistics, :epoch_time, :bigint

    change_column :forked_blocks, :number, :bigint
    change_column :forked_blocks, :timestamp, :bigint
    change_column :forked_blocks, :epoch, :bigint

    change_column :uncle_blocks, :number, :bigint
    change_column :uncle_blocks, :timestamp, :bigint
    change_column :uncle_blocks, :epoch, :bigint

    change_column :udts, :addresses_count, :bigint
    change_column :udts, :block_timestamp, :bigint
    change_column :udts, :ckb_transactions_count, :bigint
  end

  def self.down
    change_column :addresses, :cell_consumed, :decimal, precision: 30, scale: 0
    change_column :addresses, :ckb_transactions_count, :decimal, precision: 30, scale: 0
    change_column :addresses, :block_timestamp, :decimal, precision: 30, scale: 0
    change_column :addresses, :live_cells_count, :decimal, precision: 30, scale: 0
    change_column :addresses, :average_deposit_time, :decimal, precision: 30, scale: 0
    change_column :addresses, :dao_transactions_count, :decimal, precision: 30, scale: 0

    change_column :cell_outputs, :address_id, :decimal, precision: 30, scale: 0
    change_column :cell_outputs, :capacity, :decimal, precision: 30, scale: 0
    change_column :cell_outputs, :generated_by_id, :decimal, precision: 30, scale: 0
    change_column :cell_outputs, :consumed_by_id, :decimal, precision: 30, scale: 0
    change_column :cell_outputs, :block_timestamp, :decimal, precision: 30, scale: 0
    change_column :cell_outputs, :occupied_capacity, :decimal, precision: 30, scale: 0
    change_column :cell_outputs, :consumed_block_timestamp, :decimal, precision: 30, scale: 0

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
