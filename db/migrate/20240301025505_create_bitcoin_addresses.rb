class CreateBitcoinAddresses < ActiveRecord::Migration[7.0]
  def change
    create_table :bitcoin_addresses do |t|
      t.binary :address_hash, null: false

      t.timestamps
    end
  end
end
