class ChangeUniqueIndexOnBlock < ActiveRecord::Migration[5.2]
  def change
    remove_index :blocks, column: [:block_hash, :status]
    add_index :blocks, :block_hash, unique: true
  end
end
