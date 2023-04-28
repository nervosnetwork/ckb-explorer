class AddDeprecatedToContracts < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :deprecated, :boolean, defalt: false
    add_index :contracts, :deprecated
  end
end
