class AddIndexOnEpochToBlocks < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :blocks, :epoch, algorithm: :concurrently
  end
end
