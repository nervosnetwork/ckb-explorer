class DropUnusedTables < ActiveRecord::Migration[7.0]
  def change
    drop_table :pool_transaction_entries, if_exists: true
    drop_table :old_ckb_transactions, if_exists: true
    drop_table :temp_view, if_exists: true
    drop_table :tx_display_infos, if_exists: true
  end
end
