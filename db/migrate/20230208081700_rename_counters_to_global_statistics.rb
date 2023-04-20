class RenameCountersToGlobalStatistics < ActiveRecord::Migration[7.0]
  def self.up
    # remove counters and related triggers
    raw_sql = %{
DROP FUNCTION IF EXISTS increase_ckb_transactions_count() CASCADE;
DROP FUNCTION IF EXISTS decrease_ckb_transactions_count() CASCADE;
DROP TRIGGER IF EXISTS after_insert_update_ckb_transactions_count ON ckb_transactions;
DROP TRIGGER IF EXISTS after_delete_update_ckb_transactions_count ON ckb_transactions;
    }

    ActiveRecord::Base.connection.execute(raw_sql)

    drop_table :counters

    # create for global_statistics
    create_table :global_statistics do |t|
      t.string :name, comment: "the name of something, e.g. my_table_rows_count"
      t.integer :value, comment: "value of something, e.g. 888"
      t.string :comment,
               t.timestamps
    end

    # defined trigger and postgres functions
    # so that it is able to update the table's count automatically when insert/delete.
    raw_sql = %{
CREATE FUNCTION increase_ckb_transactions_count() RETURNS TRIGGER AS
$$begin
    UPDATE global_statistics SET value = value + 1 WHERE name = 'ckb_transactions';
    RETURN NEW;
end;$$
LANGUAGE PLPGSQL VOLATILE;

CREATE TRIGGER after_insert_update_ckb_transactions_count
AFTER INSERT ON ckb_transactions
FOR EACH ROW EXECUTE PROCEDURE increase_ckb_transactions_count();

CREATE FUNCTION decrease_ckb_transactions_count() RETURNS TRIGGER AS
$$begin
    UPDATE global_statistics SET value = value - 1 WHERE name = 'ckb_transactions';
    RETURN NEW;
end;$$
LANGUAGE PLPGSQL VOLATILE;

CREATE TRIGGER after_delete_update_ckb_transactions_count
AFTER DELETE ON ckb_transactions
FOR EACH ROW EXECUTE PROCEDURE decrease_ckb_transactions_count();
    }

    execute(raw_sql)

    execute <<-SQL
    BEGIN WORK;
      lock table ckb_transactions in SHARE ROW EXCLUSIVE MODE;
      insert into global_statistics
        (name, value, created_at, updated_at)
      values ('ckb_transactions', (select count(*) from ckb_transactions), now(), now())
      ;
      COMMIT WORK;
    SQL
  end

  def self.down
    # down for global_statistics
    raw_sql = %{
DROP FUNCTION IF EXISTS increase_ckb_transactions_count() CASCADE;
DROP FUNCTION IF EXISTS decrease_ckb_transactions_count() CASCADE;
DROP TRIGGER IF EXISTS after_insert_update_ckb_transactions_count ON ckb_transactions;
DROP TRIGGER IF EXISTS after_delete_update_ckb_transactions_count ON ckb_transactions;
    }

    execute(raw_sql)

    drop_table :global_statistics

    # down for counters
    create_table :counters do |t|
      t.string :name, comment: "the name of the table"
      t.integer :value, comment: "the count value of the table"
      t.timestamps
    end

    # defined trigger and postgres functions
    # so that it is able to update the table's count automatically when insert/delete.
    raw_sql = %{
CREATE FUNCTION increase_ckb_transactions_count() RETURNS TRIGGER AS
$$begin
    UPDATE counters SET value = value + 1 WHERE name = 'ckb_transactions';
    RETURN NEW;
end;$$
LANGUAGE PLPGSQL VOLATILE;

CREATE TRIGGER after_insert_update_ckb_transactions_count
AFTER INSERT ON ckb_transactions
FOR EACH ROW EXECUTE PROCEDURE increase_ckb_transactions_count();

CREATE FUNCTION decrease_ckb_transactions_count() RETURNS TRIGGER AS
$$begin
    UPDATE counters SET value = value - 1 WHERE name = 'ckb_transactions';
    RETURN NEW;
end;$$
LANGUAGE PLPGSQL VOLATILE;

CREATE TRIGGER after_delete_update_ckb_transactions_count
AFTER DELETE ON ckb_transactions
FOR EACH ROW EXECUTE PROCEDURE decrease_ckb_transactions_count();
    }

    execute(raw_sql)

    execute <<-SQL
    BEGIN WORK;
      lock table ckb_transactions in SHARE ROW EXCLUSIVE MODE;
      insert into counters
        (name, value, created_at, updated_at)
      values ('ckb_transactions', (select count(*) from ckb_transactions), now(), now())
      ;
      COMMIT WORK;
    SQL
  end
end
