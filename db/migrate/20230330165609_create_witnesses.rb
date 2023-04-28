class CreateWitnesses < ActiveRecord::Migration[7.0]
  def change
    create_table :witnesses do |t|
      t.binary :data, null: false
      t.references :ckb_transaction, null: false, foreign_key: true
      t.integer :index, null: false
    end

    add_index :witnesses, [:ckb_transaction_id, :index], unique: true
  end
end
