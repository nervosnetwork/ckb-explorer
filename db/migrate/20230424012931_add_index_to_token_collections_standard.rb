class AddIndexToTokenCollectionsStandard < ActiveRecord::Migration[7.0]
  def change
    add_index :token_collections, :standard
  end
end
