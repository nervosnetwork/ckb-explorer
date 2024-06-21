class AddTagsToTokenCollection < ActiveRecord::Migration[7.0]
  def change
    add_column :token_collections, :tags, :string, array: true, default: []
    add_column :token_collections, :block_timestamp, :bigint
  end
end
