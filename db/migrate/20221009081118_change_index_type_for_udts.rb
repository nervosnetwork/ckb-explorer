class ChangeIndexTypeForUdts < ActiveRecord::Migration[6.1]
  def self.up
    remove_index :udts, name: "index_udts_on_type_hash"
    add_index :udts, :type_hash, using: 'hash'
  end

  def self.down
    remove_index :udts, name: "index_udts_on_type_hash"
    add_index :udts, :type_hash
  end
end
