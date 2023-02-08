class CreateScripts < ActiveRecord::Migration[7.0]
  def change
    create_table :scripts do |t|
      t.string :args
      t.string :script_hash
      t.boolean :is_contract, default: false
      t.bigint :contract_id

      t.timestamps null: false
    end
  end
end
