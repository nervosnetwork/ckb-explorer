class RemoveAddressDaoTransaction < ActiveRecord::Migration[7.0]
  def change
    drop_table :address_dao_transactions, if_exists: true
  end
end
