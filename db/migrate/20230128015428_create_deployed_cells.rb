class CreateDeployedCells < ActiveRecord::Migration[7.0]
  def change
    create_table :deployed_cells do |t|
      t.bigint :cell_id
      t.bigint :contract_id
      t.boolean :is_initialized, default: false

      t.timestamps null: false
    end
  end
end
