class DropGlobalStatistic < ActiveRecord::Migration[7.0]
  def change
    drop_table :global_statistics, if_exists: true
    sql = <<-SQL
     DROP TRIGGER IF EXISTS after_delete_update_ckb_transactions_count ON ckb_transactions;
     DROP TRIGGER IF EXISTS after_insert_update_ckb_transactions_count ON ckb_transactions;
     DROP TRIGGER IF EXISTS after_update_ckb_transactions_count ON ckb_transactions;

     DROP FUNCTION IF EXISTS public.decrease_ckb_transactions_count();
     DROP FUNCTION IF EXISTS public.increase_ckb_transactions_count();
     DROP FUNCTION IF EXISTS public.update_ckb_transactions_count();
    SQL
    ActiveRecord::Base.connection.execute(sql)
  end
end
