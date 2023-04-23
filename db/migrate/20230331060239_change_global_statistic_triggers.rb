class ChangeGlobalStatisticTriggers < ActiveRecord::Migration[7.0]
  def change
    execute <<~SQL
      insert into global_statistics(name, value, created_at, updated_at)
      values
      ('pending_transactions', 0, now(), now()),
      ('committed_transactions', 0, now(), now())
       on conflict do nothing;
    SQL
    execute <<~SQL
      CREATE or replace FUNCTION increase_ckb_transactions_count()
      RETURNS TRIGGER AS
      $$begin

        UPDATE global_statistics SET value = value + 1 WHERE name = 'ckb_transactions';
        if new.tx_status = 0 then
          update global_statistics SET value = value + 1 where name = 'pending_transactions';
        end if;
        if new.tx_status = 2 then
          update global_statistics SET value = value + 1 where name = 'committed_transactions';
        end if;
        RETURN NEW;
      end;$$
      LANGUAGE PLPGSQL VOLATILE;
    SQL

    execute <<~SQL
      CREATE or replace FUNCTION update_ckb_transactions_count()
        RETURNS TRIGGER AS
        $$begin
          if new.tx_status = 0 then
            update global_statistics SET value = value + 1 where name = 'pending_transactions';
          end if;
          if new.tx_status = 2 then
            update global_statistics SET value = value + 1 where name = 'committed_transactions';
          end if;
          RETURN NEW;
        end;$$
        LANGUAGE PLPGSQL VOLATILE;
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION decrease_ckb_transactions_count() RETURNS TRIGGER AS
      $$begin
          UPDATE global_statistics SET value = value - 1 WHERE name = 'ckb_transactions';
          if new.tx_status = 0 then
            update global_statistics SET value = value - 1 where name = 'pending_transactions';
          end if;
          if new.tx_status = 2 then
            update global_statistics SET value = value - 1 where name = 'committed_transactions';
          end if;
          RETURN NEW;
      end;$$
      LANGUAGE PLPGSQL VOLATILE;
    SQL
  end
end
