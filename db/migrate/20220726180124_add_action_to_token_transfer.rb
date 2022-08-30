class AddActionToTokenTransfer < ActiveRecord::Migration[6.1]
  def change
    add_column :token_transfers, :action, :integer
    change_column :token_transfers, :from_id, :integer, null: true
    change_column :token_transfers, :to_id, :integer, null: true
  end
end
