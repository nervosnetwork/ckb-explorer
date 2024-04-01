class ChangeBitcoinVoutsIndex < ActiveRecord::Migration[7.0]
  def change
    remove_index :bitcoin_vouts, column: %i[bitcoin_transaction_id index], if_exists: true
    add_index :bitcoin_vouts, %i[bitcoin_transaction_id index cell_output_id], unique: true, name: :index_vouts_uniqueness
  end
end
