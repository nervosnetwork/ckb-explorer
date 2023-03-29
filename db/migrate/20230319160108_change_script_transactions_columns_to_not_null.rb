class ChangeScriptTransactionsColumnsToNotNull < ActiveRecord::Migration[7.0]
  def change
    change_column_null :script_transactions, :script_id, false
    change_column_null :script_transactions, :ckb_transaction_id, false
  end
end
