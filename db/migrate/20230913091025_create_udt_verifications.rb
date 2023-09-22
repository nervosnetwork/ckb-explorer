class CreateUdtVerifications < ActiveRecord::Migration[7.0]
  def change
    create_table :udt_verifications do |t|
      t.integer :token
      t.datetime :sent_at
      t.inet :last_ip
      t.belongs_to :udt
      t.integer :udt_type_hash

      t.timestamps
      t.index :udt_type_hash, unique: true
    end
  end
end
