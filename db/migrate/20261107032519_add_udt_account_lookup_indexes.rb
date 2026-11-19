class AddUdtAccountLookupIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # Rails 7.0's PostgreSQL adapter does not support :include, but the live
    # partition is the only one queried by UDT balance sums, so keep udt_amount
    # in the index to allow index-only scans.
    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_cell_outputs_live_on_address_type_cell_and_udt_amount
      ON cell_outputs_live (address_id, type_hash, cell_type)
      INCLUDE (udt_amount)
    SQL

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_udt_accounts_on_address_type_and_udt_type
      ON udt_accounts (address_id, type_hash, udt_type)
    SQL
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_udt_accounts_on_address_type_and_udt_type"
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_cell_outputs_live_on_address_type_cell_and_udt_amount"
  end
end
