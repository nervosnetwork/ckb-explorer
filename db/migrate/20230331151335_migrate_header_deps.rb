class MigrateHeaderDeps < ActiveRecord::Migration[7.0]
  def change
    HeaderDependency.migrate_old
  end
end
