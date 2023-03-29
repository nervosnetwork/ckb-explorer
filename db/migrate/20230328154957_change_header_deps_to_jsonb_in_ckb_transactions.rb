class ChangeHeaderDepsToJsonbInCkbTransactions < ActiveRecord::Migration[7.0]
  def up
    change_column :ckb_transactions, :header_deps, :text
  end

  def down
    change_column :ckb_transactions, :header_deps, :binary
  end
end
