class AddIndexOnNumberToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_index :blocks, :number
  end
end
