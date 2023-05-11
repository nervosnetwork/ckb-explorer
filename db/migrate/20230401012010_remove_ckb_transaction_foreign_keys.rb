class RemoveCkbTransactionForeignKeys < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :udt_transactions, :ckb_transactions
    remove_foreign_key :block_transactions, :ckb_transactions
    remove_foreign_key :header_dependencies, :ckb_transactions
    remove_foreign_key :witnesses, :ckb_transactions
  end
end
