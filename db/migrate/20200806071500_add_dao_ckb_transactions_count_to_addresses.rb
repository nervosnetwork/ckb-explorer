class AddDaoCkbTransactionsCountToAddresses < ActiveRecord::Migration[6.0]
  def change
    add_column :addresses, :dao_transactions_count, :decimal, precision: 30, default: 0
  end
end
