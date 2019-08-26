class AddHeaderDepsAndCellDepsToCkbTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :ckb_transactions, :header_deps, :binary
    add_column :ckb_transactions, :cell_deps, :jsonb
  end
end
