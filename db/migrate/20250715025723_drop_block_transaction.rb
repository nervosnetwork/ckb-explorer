class DropBlockTransaction < ActiveRecord::Migration[7.0]
  def change
    drop_table :block_transactions, if_exists: true
  end
end
