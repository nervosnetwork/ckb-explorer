class AddBytesToPoolTransaction < ActiveRecord::Migration[6.1]
  def change
    add_column :pool_transaction_entries, :bytes, :integer, default: 0
  end
end
