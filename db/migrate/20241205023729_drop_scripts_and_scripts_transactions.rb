class DropScriptsAndScriptsTransactions < ActiveRecord::Migration[7.0]
  def change
    drop_table :scripts, if_exists: true
    drop_table :script_transactions, if_exists: true
    drop_table :deployed_cells, if_exists: true
    drop_table :referring_cells, if_exists: true
    drop_table :transaction_propagation_delays, if_exists: true
  end
end
