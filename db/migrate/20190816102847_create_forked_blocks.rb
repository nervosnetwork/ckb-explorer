class CreateForkedBlocks < ActiveRecord::Migration[5.2]
  def change
    create_table :forked_blocks do |t|
      t.string :difficulty, limit: 66
      t.binary :block_hash
      t.decimal :number, precision: 30, scale: 0
      t.binary :parent_hash
      t.jsonb :seal
      t.decimal :timestamp, precision: 30, scale: 0
      t.binary :transactions_root
      t.binary :proposals_hash
      t.integer :uncles_count
      t.binary :uncles_hash
      t.binary :uncle_block_hashes
      t.integer :version
      t.binary :proposals
      t.integer :proposals_count
      t.decimal :cell_consumed, precision: 30, scale: 0
      t.binary :miner_hash
      t.decimal :reward, precision: 30
      t.decimal :total_transaction_fee, precision: 30, scale: 0
      t.decimal :ckb_transactions_count, precision: 30, scale: 0, default: 0
      t.decimal :total_cell_capacity, precision: 30, scale: 0
      t.binary :witnesses_root
      t.decimal :epoch, precision: 30, scale: 0
      t.string :start_number
      t.string :length
      t.string :address_ids, array: true
      t.integer :reward_status, default: 0
      t.integer :received_tx_fee_status, default: 0
      t.decimal :received_tx_fee, precision: 30, scale: 0, default: 0
      t.integer :target_block_reward_status, default: 0
      t.binary :miner_lock_hash
      t.string :dao

      t.timestamps
    end
  end
end
