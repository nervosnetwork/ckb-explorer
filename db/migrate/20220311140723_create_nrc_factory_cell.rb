class CreateNrcFactoryCell < ActiveRecord::Migration[6.1]
  def change
    create_table :nrc_factory_cells do |t|
      t.binary :code_hash
      t.string :hash_type
      t.string :args
      t.string :name
      t.string :symbol
      t.string :base_token_uri
      t.string :extra_data
      t.boolean :verified, default: false

      t.timestamps
    end

    add_index :nrc_factory_cells, [:code_hash, :hash_type, :args], unique: true
  end
end
