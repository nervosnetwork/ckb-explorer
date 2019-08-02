class RemoveUselessColumnFromCkbTransactions < ActiveRecord::Migration[5.2]
  def change
    remove_column :ckb_transactions, :status, :integer
    remove_column :ckb_transactions, :display_inputs_status, :integer
    remove_column :ckb_transactions, :transaction_fee_status, :integer
    remove_column :ckb_transactions, :display_inputs, :jsonb
    remove_column :ckb_transactions, :display_outputs, :jsonb
  end
end
