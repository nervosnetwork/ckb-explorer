class RemoveFunctionFromStructure < ActiveRecord::Migration[7.0]
  def change
    sql = <<-SQL.squish
      DROP FUNCTION IF EXISTS public.synx_tx_to_account_book();
      DROP FUNCTION IF EXISTS public.array_subtract(minuend anyarray, subtrahend anyarray, OUT difference anyarray);
      DROP FUNCTION IF EXISTS public.update_cell_dependencies_implicit();
      DROP FUNCTION IF EXISTS public.insert_into_ckb_transactions();
      DROP PROCEDURE IF EXISTS public.sync_full_account_book();
      DROP PROCEDURE IF EXISTS public.update_cell_inputs();
    SQL
    ActiveRecord::Base.connection.execute(sql)
  end
end
