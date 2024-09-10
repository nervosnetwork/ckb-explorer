class ChangeCkbTransactionConfirmationTime < ActiveRecord::Migration[7.0]
  def change
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    change_column :ckb_transactions, :confirmation_time, :bigint
  end
end
