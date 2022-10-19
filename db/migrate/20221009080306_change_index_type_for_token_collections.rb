class ChangeIndexTypeForTokenCollections< ActiveRecord::Migration[6.1]
  def self.up
    remove_index :token_collections, name: "index_token_collections_on_sn"
    add_index :token_collections, :sn, using: 'hash'
    execute "alter table public.token_collections add constraint unique_sn unique (sn);"
  end

  def self.down
    execute "alter table public.token_collections drop constraint unique_sn;"
    remove_index :token_collections, name: "index_token_collections_on_sn"
    add_index :token_collections, :sn
  end
end
