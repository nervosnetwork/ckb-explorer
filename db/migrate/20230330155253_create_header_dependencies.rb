class CreateHeaderDependencies < ActiveRecord::Migration[7.0]
  def change
    create_table :header_dependencies do |t|
      t.binary :header_hash, null: false
      t.references :ckb_transaction, null: false, foreign_key: true
      t.integer :index, null: false
    end
    add_index :header_dependencies, [:ckb_transaction_id, :index], unique: true
  end
end
