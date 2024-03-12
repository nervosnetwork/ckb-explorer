class AddAddressesCountToContract < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :addresses_count, :integer
  end
end
