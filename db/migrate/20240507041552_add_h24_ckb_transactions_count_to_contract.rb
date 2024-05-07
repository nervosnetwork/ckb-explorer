class AddH24CkbTransactionsCountToContract < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :h24_ckb_transactions_count, :integer
  end
end
