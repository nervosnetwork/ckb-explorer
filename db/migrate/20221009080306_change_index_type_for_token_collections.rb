class ChangeIndexTypeForTokenCollections< ActiveRecord::Migration[6.1]
  def self.up
    remove_index :token_collections, name: "index_token_collections_on_sn"
    add_index :token_collections, :sn, using: 'hash'
  end

  def self.down
    remove_index :token_collections, name: "index_token_collections_on_sn"
    add_index :token_collections, :sn
  end
end
