class CreateRejectReasons < ActiveRecord::Migration[7.0]
  def change
    create_table :reject_reasons do |t|
      t.bigint :ckb_transaction_id, null: false
      t.text :message
    end
    add_index :reject_reasons, :ckb_transaction_id, unique: true
  end
end
