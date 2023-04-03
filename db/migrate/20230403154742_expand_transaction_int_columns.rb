class ExpandTransactionIntColumns < ActiveRecord::Migration[7.0]
  def up
    change_column :ckb_transactions, :bytes, :bigint
    change_column :ckb_transactions, :cycles, :bigint
    # Ex:- change_column("admin_users", "email", :string, :limit =>25)
  end

  def down
    change_column :ckb_transactions, :bytes, :integer
    change_column :ckb_transactions, :cycles, :integer
  end
end
