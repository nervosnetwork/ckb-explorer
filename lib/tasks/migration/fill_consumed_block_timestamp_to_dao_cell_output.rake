namespace :migration do
  task fill_consumed_block_timestamp_to_dao_cell_output: :environment do
    progress_bar = ProgressBar.create({
      total: CellOutput.count,
      format: "%e %B %p%% %c/%C"
    })

    values =
      CellOutput.all.map do |cell_output|
        progress_bar.increment
        [cell_output.id, cell_output.block_id, cell_output.ckb_transaction_id, cell_output.address_id, cell_output.generated_by_id,
        cell_output.consumed_by_id, cell_output.consumed_by&.block_timestamp]
      end

    columns = [:id, :block_id, :ckb_transaction_id, :address_id, :generated_by_id, :consumed_by_id, :consumed_block_timestamp]
    CellOutput.import columns, values, on_duplicate_key_update: [:consumed_block_timestamp]

    puts "done"
  end
end
