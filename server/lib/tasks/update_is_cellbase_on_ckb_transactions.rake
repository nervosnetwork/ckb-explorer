task update_is_cellbase_on_ckb_transactions: :environment do
  CkbTransaction.where(id: CellInput.where(from_cell_base: true).select("ckb_transaction_id")).update_all(is_cellbase: true)
end