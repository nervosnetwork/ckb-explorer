class CreateCellDependencies < ActiveRecord::Migration[7.0]
  def change
    create_table :cell_dependencies do |t|
      t.bigint :contract_id
      t.bigint :ckb_transaction_id
      t.integer :dep_type
      t.bigint :contract_cell_id

      t.timestamps null: false
    end
  end
end
