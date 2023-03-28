class ChangeHeaderDepsToJsonbInCkbTransactions < ActiveRecord::Migration[7.0]
  def up
    remove_column :ckb_transactions, :header_deps
    add_column :ckb_transactions, :header_deps, :jsonb
  end

  def down
    change_column :ckb_transactions, :header_deps, :binary
  end
end
