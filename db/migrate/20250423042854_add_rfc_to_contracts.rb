class AddRfcToContracts < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :rfc, :string
    add_column :contracts, :source_url, :string
    add_column :contracts, :dep_type, :integer
    remove_column :contracts, :code_hash
    remove_column :contracts, :role
    remove_column :contracts, :symbol
  end
end
