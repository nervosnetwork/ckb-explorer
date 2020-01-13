namespace :migration do
  task update_tx_live_cell_changes_and_capacity_involved: :environment do
    progress_bar = ProgressBar.create({ total: CkbTransaction.count, format: "%e %B %p%% %c/%C" })
    columns = [:id, :block_id, :live_cell_changes, :capacity_involved]
    CkbTransaction.order(:id).find_in_batches(batch_size: 4000) do |ckb_transactions|
      values =
        ckb_transactions.map do |ckb_transaction|
          progress_bar.increment
          live_cell_changes = ckb_transaction.is_cellbase ? 1 : ckb_transaction.outputs.count - ckb_transaction.inputs.count
          capacity_involved = ckb_transaction.inputs.sum(:capacity)
          [ckb_transaction.id, ckb_transaction.block_id, live_cell_changes, capacity_involved]
        end

      CkbTransaction.import! columns, values, validate:false, on_duplicate_key_update: [:live_cell_changes, :capacity_involved]
    end

    puts "done"
  end
end
