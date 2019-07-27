class AddDaoToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :dao, :string
  end
end
