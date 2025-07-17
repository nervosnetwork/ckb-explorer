class DropTransactionAddressChange < ActiveRecord::Migration[7.0]
  def change
    drop_table :transaction_address_changes, if_exists: true
  end
end
