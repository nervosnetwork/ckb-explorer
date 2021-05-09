class AddIndexOnTypeAndLocks < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :lock_scripts, [:code_hash, :hash_type, :args], algorithm: :concurrently
    add_index :type_scripts, [:code_hash, :hash_type, :args], algorithm: :concurrently
  end
end
