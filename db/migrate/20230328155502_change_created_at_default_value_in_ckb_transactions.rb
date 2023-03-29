class ChangeCreatedAtDefaultValueInCkbTransactions < ActiveRecord::Migration[7.0]
  def change
    change_column_default :ckb_transactions, :created_at, from: nil, to: -> { "NOW()" }
    change_column_default :ckb_transactions, :updated_at, from: nil, to: -> { "NOW()" }
  end
end
