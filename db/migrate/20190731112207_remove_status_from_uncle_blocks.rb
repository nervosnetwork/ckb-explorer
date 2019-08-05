class RemoveStatusFromUncleBlocks < ActiveRecord::Migration[5.2]
  def change
    remove_column :uncle_blocks, :status, :integer
  end
end
