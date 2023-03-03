class AddConfirmationTimeToCkbTransactions < ActiveRecord::Migration[7.0]
  def change
    add_column :ckb_transactions, :confirmation_time, :integer, comment: 'it cost how many seconds to confirm this transaction'
  end
end
