class AddDetailedMessageToPoolTransactionEntries < ActiveRecord::Migration[6.1]
  def change
    add_column :pool_transaction_entries, :detailed_message, :text
  end
end
