class AddExtensionToBlocks < ActiveRecord::Migration[6.1]
  def change
    add_column :blocks, :extension, :jsonb
    add_column :forked_blocks, :extension, :jsonb
  end
end
