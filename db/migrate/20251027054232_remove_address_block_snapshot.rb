class RemoveAddressBlockSnapshot < ActiveRecord::Migration[7.0]
  def change
    drop_table :address_block_snapshots, if_exists: true
  end
end
