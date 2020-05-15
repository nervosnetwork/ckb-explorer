class AddIndexToBlockSizeOnBlock < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :blocks, :block_size, algorithm: :concurrently
    add_index :blocks, :block_time, algorithm: :concurrently
  end
end
