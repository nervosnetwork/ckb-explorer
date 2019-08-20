class ChangeWitnessesToJsonbInCkbTransactions < ActiveRecord::Migration[5.2]
  def change
    remove_column :ckb_transactions, :witnesses, :jsonb
    add_column :ckb_transactions, :witnesses, :jsonb
  end
end
