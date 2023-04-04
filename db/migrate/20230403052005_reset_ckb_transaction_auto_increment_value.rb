class ResetCkbTransactionAutoIncrementValue < ActiveRecord::Migration[7.0]
  def change
    max_ckb_tx_id = CkbTransaction.maximum(:id)
    if max_ckb_tx_id
      ActiveRecord::Base.connection.execute("ALTER SEQUENCE ckb_transactions_id_seq RESTART WITH #{max_ckb_tx_id + 1}")
    end
  end
end
