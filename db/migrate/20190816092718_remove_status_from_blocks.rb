class RemoveStatusFromBlocks < ActiveRecord::Migration[5.2]
  def change
    remove_column :blocks, :status
  end
end
