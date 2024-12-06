class ChangeCkbTransactionConfirmationTime < ActiveRecord::Migration[7.0]
  def change
    execute("SET statement_timeout = 0;")
    change_column :ckb_transactions, :confirmation_time, :bigint
    execute "RESET statement_timeout;"
  end
end
