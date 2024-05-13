class CreateBitcoinAnnotations < ActiveRecord::Migration[7.0]
  def change
    create_table :bitcoin_annotations do |t|
      t.bigint :ckb_transaction_id
      t.integer :leap_direction
      t.integer :transfer_step
      t.string :tags, default: [], array: true

      t.timestamps
    end

    add_index :bitcoin_annotations, :ckb_transaction_id, unique: true
  end
end
