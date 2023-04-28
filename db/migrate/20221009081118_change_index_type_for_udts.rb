class ChangeIndexTypeForUdts < ActiveRecord::Migration[6.1]
  def self.up
    remove_index :udts, name: "index_udts_on_type_hash"
    add_index :udts, :type_hash, using: 'hash'
    execute "alter table public.udts add constraint unique_type_hash unique (type_hash);"
  end

  def self.down
    execute "alter table public.udts drop constraint unique_type_hash;"
    remove_index :udts, name: "index_udts_on_type_hash"
    add_index :udts, :type_hash
  end
end
