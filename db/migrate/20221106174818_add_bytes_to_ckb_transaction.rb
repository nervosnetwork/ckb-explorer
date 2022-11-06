class AddBytesToCkbTransaction < ActiveRecord::Migration[6.1]
  def change
    add_column :ckb_transactions, :bytes, :integer, default: 0
  end
end
