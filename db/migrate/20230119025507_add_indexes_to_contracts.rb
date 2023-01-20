class AddIndexesToContracts < ActiveRecord::Migration[7.0]
  def change
    add_index :contracts, :code_hash
    add_index :contracts, :hash_type
    add_index :contracts, :name
    add_index :contracts, :role
    add_index :contracts, :symbol
    add_index :contracts, :verified
  end
end
