class RecreateCkbTransactionTriggers < ActiveRecord::Migration[7.0]
  def change
    execute <<~SQL

      CREATE TRIGGER after_insert_update_ckb_transactions_count
      AFTER INSERT ON ckb_transactions
      FOR EACH ROW EXECUTE PROCEDURE increase_ckb_transactions_count();

      CREATE TRIGGER after_update_ckb_transactions_count
      AFTER UPDATE ON ckb_transactions
      FOR EACH ROW EXECUTE PROCEDURE update_ckb_transactions_count();

      CREATE TRIGGER after_delete_update_ckb_transactions_count
      AFTER DELETE ON ckb_transactions
      FOR EACH ROW EXECUTE PROCEDURE decrease_ckb_transactions_count();
    SQL
  end
end
