class RemoveDepsFromCkbTransactions < ActiveRecord::Migration[6.0]
  def change
    remove_column :ckb_transactions, :deps
  end
end
