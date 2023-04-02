class MigrateHeaderDeps < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    HeaderDependency.migrate_old
  end
end
