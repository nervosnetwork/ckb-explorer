
class CreateCkbTransactionAccountBookTrigger < ActiveRecord::Migration[6.1]
  def self.up
    execute 'TRUNCATE account_books'
    # remove unused fields
    remove_column :account_books, :created_at
    remove_column :account_books, :updated_at
    # add new index
    add_index :account_books, [:address_id, :ckb_transaction_id], :unique => true
    # remove old index
    remove_index :account_books, :address_id

    # create util function
    execute <<-sql
CREATE OR REPLACE FUNCTION array_subtract(
	minuend anyarray,
	subtrahend anyarray,
	OUT difference anyarray)
    RETURNS anyarray
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE STRICT PARALLEL UNSAFE
AS $BODY$
begin
    execute 'select array(select unnest($1) except select unnest($2))'
      using minuend, subtrahend
       into difference;
end;
$BODY$;
    sql
    # create trigger function
    execute <<-sql
CREATE OR REPLACE FUNCTION synx_tx_to_account_book()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
DECLARE
  i int;
  to_add int[];
  to_remove int[];
   BEGIN
   RAISE NOTICE 'trigger ckb tx(%)', new.id;
   if new.contained_address_ids is null then
   	new.contained_address_ids := array[]::int[];
	end if;
	if old is null 
	then
		to_add := new.contained_address_ids;
		to_remove := array[]::int[];
	else
	
	   to_add := array_subtract(new.contained_address_ids, old.contained_address_ids);
	   to_remove := array_subtract(old.contained_address_ids, new.contained_address_ids);	
	end if;

   if to_add is not null then
	   FOREACH i IN ARRAY to_add
	   LOOP 
	   	RAISE NOTICE 'ckb_tx_addr_id(%)', i;
			insert into account_books (ckb_transaction_id, address_id) 
			values (new.id, i);
	   END LOOP;
	end if;
	if to_remove is not null then
	   delete from account_books where ckb_transaction_id = new.id and address_id = ANY(to_remove);
	end if;
      RETURN NEW;
   END;
$BODY$;
    sql

    execute "DROP TRIGGER IF EXISTS sync_to_account_book ON ckb_transactions"
    # create trigger
    execute <<-sql
    CREATE TRIGGER sync_to_account_book
    AFTER INSERT OR UPDATE 
    ON ckb_transactions
    FOR EACH ROW
    EXECUTE FUNCTION synx_tx_to_account_book();
    sql

    # create migration procedure
    execute <<-sql
CREATE OR REPLACE PROCEDURE sync_full_account_book(
	)
LANGUAGE 'plpgsql'
AS $BODY$
declare
    c cursor for select * from ckb_transactions;
    i int;
     row  RECORD;
begin
    open c;
    LOOP
      FETCH FROM c INTO row;
      EXIT WHEN NOT FOUND;
      foreach i in array row.contained_address_ids loop
        insert into account_books (ckb_transaction_id, address_id)
        values (row.id, i) ON CONFLICT DO NOTHING;
        end loop;
    END LOOP;    
    close c;
end
$BODY$;
  sql

    execute 'CALL sync_full_account_book()'
  end

  def self.down
  end
end
