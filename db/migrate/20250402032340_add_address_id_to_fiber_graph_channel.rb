class AddAddressIdToFiberGraphChannel < ActiveRecord::Migration[7.0]
  def change
    change_table :fiber_graph_channels, bulk: true do |t|
      t.bigint :cell_output_id
      t.bigint :address_id
      t.index :address_id
    end
  end
end
