class CreateTiggerForSyncingPendingTx < ActiveRecord::Migration[7.0]
  def self.up
    execute <<~SQL
          CREATE OR REPLACE FUNCTION insert_into_ckb_transactions()
      RETURNS TRIGGER AS $$
      BEGIN
        INSERT INTO ckb_transactions
        (tx_status, tx_hash, cell_deps, header_deps,
        witnesses, bytes, cycles, version,
        transaction_fee
        )
        VALUES
        (NEW.tx_status, NEW.tx_hash, NEW.cell_deps, NEW.header_deps,
        NEW.witnesses, NEW.tx_size, NEW.cycles, NEW.version,
        NEW.transaction_fee
        );
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
    execute <<~SQL
          CREATE TRIGGER insert_ckb_transactions
      AFTER INSERT ON pool_transaction_entries
      FOR EACH ROW
      EXECUTE FUNCTION insert_into_ckb_transactions();
    SQL
  end

  def self.down
    execute <<-SQL
    DROP TRIGGER insert_ckb_transactions ON pool_transaction_entries
    SQL

    execute "DROP FUNCTION insert_into_ckb_transactions()"
  end
end
