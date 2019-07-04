class AddStatusToUncleBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :uncle_blocks, :status, :integer, default: 0
  end
end
