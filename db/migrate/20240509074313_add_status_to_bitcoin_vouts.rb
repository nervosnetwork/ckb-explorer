class AddStatusToBitcoinVouts < ActiveRecord::Migration[7.0]
  def change
    add_column :bitcoin_vouts, :status, :integer, default: 0
    add_column :bitcoin_vouts, :consumed_by_id, :bigint

    add_index :bitcoin_vouts, :status
    add_index :bitcoin_vouts, :consumed_by_id
  end
end
