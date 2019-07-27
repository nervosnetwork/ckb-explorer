class AddDaoToUncleBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :uncle_blocks, :dao, :string
  end
end
